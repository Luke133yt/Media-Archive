import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'tmdb.dart';

/// Server HTTP locale compatibile con addons Stremio/Nuvio.
/// Espone cataloghi della collezione fisica e stream “in archivio”.
class NuvioAddonServer {
  NuvioAddonServer._();
  static final NuvioAddonServer instance = NuvioAddonServer._();

  HttpServer? _server;
  List<MediaItem> Function()? _items;
  int _port = 7001;
  String? _lanHost;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get manifestUrl {
    if (_server == null) return null;
    final host = _lanHost ?? InternetAddress.loopbackIPv4.address;
    return 'http://$host:$_port/manifest.json';
  }

  Future<String> start(List<MediaItem> Function() items,
      {int port = 7001}) async {
    if (_server != null) {
      _items = items;
      return manifestUrl!;
    }
    _items = items;
    _port = port;
    _lanHost = await _guessLanIp();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen(_handle);
    return manifestUrl!;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void refresh() {
    // I dati sono letti live da [_items]; nessun cache da invalidare.
  }

  Future<String?> _guessLanIp() async {
    try {
      for (final iface in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false)) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handle(HttpRequest request) async {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    try {
      final path = request.uri.path;
      if (path == '/' || path == '/configure') {
        _html(request.response, _configureHtml(manifestUrl ?? ''));
        return;
      }
      if (path == '/manifest.json') {
        _json(request.response, _manifest());
        return;
      }
      if (path == '/catalog.json' || path == '/export.json') {
        _json(request.response, {
          'app': 'media_archive',
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'items': (_items?.call() ?? const <MediaItem>[])
              .map(_itemJson)
              .toList(),
        });
        return;
      }
      final catalog = RegExp(r'^/catalog/(movie|series)/([^/]+)\.json$')
          .firstMatch(path);
      if (catalog != null) {
        _json(
            request.response,
            _catalog(
              catalog.group(1)!,
              catalog.group(2)!,
              search: request.uri.queryParameters['search'],
            ));
        return;
      }
      final meta =
          RegExp(r'^/meta/(movie|series)/([^/]+)\.json$').firstMatch(path);
      if (meta != null) {
        final item = _find(meta.group(2)!);
        if (item == null) {
          request.response.statusCode = 404;
          _json(request.response, {'meta': null});
          return;
        }
        _json(request.response, {'meta': _meta(item)});
        return;
      }
      final stream =
          RegExp(r'^/stream/(movie|series)/([^/]+)\.json$').firstMatch(path);
      if (stream != null) {
        final matches = _findAll(stream.group(2)!);
        _json(request.response, {
          'streams': [
            for (final item in matches) _ownershipStream(item),
          ],
        });
        return;
      }
      request.response.statusCode = 404;
      _json(request.response, {'error': 'not found'});
    } catch (e) {
      request.response.statusCode = 500;
      _json(request.response, {'error': e.toString()});
    }
  }

  void _cors(HttpResponse res) {
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', '*')
      ..set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  }

  void _json(HttpResponse res, Object body) {
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    res.close();
  }

  void _html(HttpResponse res, String body) {
    res.headers.contentType = ContentType.html;
    res.write(body);
    res.close();
  }

  Map<String, dynamic> _manifest() => {
        'id': 'com.luke133yt.mediaarchive',
        'version': '1.13.0',
        'name': 'Media Archive',
        'description':
            'Collezione di media fisici (DVD, Blu-ray, VHS…). Mostra se un titolo è nel tuo archivio e con quale supporto.',
        'logo':
            'https://raw.githubusercontent.com/Luke133yt/Media-Archive/main/assets/branding/media_archive_logo.png',
        'background':
            'https://raw.githubusercontent.com/Luke133yt/Media-Archive/main/assets/branding/media_archive_logo.png',
        'resources': [
          'catalog',
          {'name': 'meta', 'types': ['movie', 'series'], 'idPrefixes': ['tmdb', 'tt', 'mediaarchive']},
          {'name': 'stream', 'types': ['movie', 'series'], 'idPrefixes': ['tmdb', 'tt', 'mediaarchive']},
        ],
        'types': ['movie', 'series'],
        'idPrefixes': ['tmdb', 'tt', 'mediaarchive'],
        'catalogs': [
          {
            'type': 'movie',
            'id': 'mediaarchive',
            'name': 'Physical · Movies',
            'extra': [
              {'name': 'search', 'isRequired': false},
              {'name': 'skip', 'isRequired': false},
            ],
          },
          {
            'type': 'series',
            'id': 'mediaarchive',
            'name': 'Physical · Series',
            'extra': [
              {'name': 'search', 'isRequired': false},
              {'name': 'skip', 'isRequired': false},
            ],
          },
          {
            'type': 'movie',
            'id': 'mediaarchive-top',
            'name': 'Physical · Top rated',
            'extra': [
              {'name': 'skip', 'isRequired': false},
            ],
          },
          {
            'type': 'movie',
            'id': 'mediaarchive-recent',
            'name': 'Physical · Recently added',
            'extra': [
              {'name': 'skip', 'isRequired': false},
            ],
          },
        ],
        'behaviorHints': {
          'configurable': true,
          'configurationRequired': false,
        },
      };

  Map<String, dynamic> _catalog(String type, String id, {String? search}) {
    final wantTv = type == 'series';
    var items = (_items?.call() ?? const <MediaItem>[])
        .where((e) => e.isTv == wantTv && e.tmdbId != null)
        .toList();
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      items = items
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.originalTitle.toLowerCase().contains(q))
          .toList();
    }
    if (id == 'mediaarchive-top') {
      items.sort((a, b) =>
          (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0));
    } else if (id == 'mediaarchive-recent') {
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } else {
      items.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return {
      'metas': [for (final item in items.take(100)) _meta(item)],
    };
  }

  MediaItem? _find(String rawId) {
    final all = _findAll(rawId);
    return all.isEmpty ? null : all.first;
  }

  List<MediaItem> _findAll(String rawId) {
    final id = Uri.decodeComponent(rawId);
    final items = _items?.call() ?? const <MediaItem>[];
    if (id.startsWith('mediaarchive:')) {
      final local = id.substring('mediaarchive:'.length);
      return items.where((e) => e.id == local).toList();
    }
    if (id.startsWith('tmdb:')) {
      final tmdb = int.tryParse(id.substring(5));
      if (tmdb == null) return const [];
      return items.where((e) => e.tmdbId == tmdb).toList();
    }
    if (id.startsWith('tt')) {
      // Senza IMDb in archivio: match per id grezzo non disponibile.
      // I client passano spesso anche tmdb; qui restituiamo vuoto se non match.
      return const [];
    }
    final asInt = int.tryParse(id);
    if (asInt != null) {
      return items.where((e) => e.tmdbId == asInt).toList();
    }
    return const [];
  }

  Map<String, dynamic> _meta(MediaItem item) {
    final type = item.isTv ? 'series' : 'movie';
    final id = item.tmdbId != null
        ? 'tmdb:${item.tmdbId}'
        : 'mediaarchive:${item.id}';
    final poster = item.posterPath == null || item.posterPath!.isEmpty
        ? null
        : TmdbClient.img(item.posterPath, size: 'w500');
    final backdrop = item.backdropPath == null || item.backdropPath!.isEmpty
        ? null
        : TmdbClient.img(item.backdropPath, size: 'w780');
    return {
      'id': id,
      'type': type,
      'name': item.title,
      'poster': poster,
      'background': backdrop,
      'posterShape': 'poster',
      'description': _description(item),
      'releaseInfo': item.year?.toString(),
      'imdbRating': item.voteAverage?.toStringAsFixed(1),
      'genres': item.genres,
      'runtime': item.runtime == null ? null : '${item.runtime} min',
      'director': item.director == null ? null : [item.director],
      'cast': item.cast.map((c) => c.name).toList(),
      'links': [
        {
          'name': item.format,
          'category': 'Physical format',
          'url': 'https://github.com/Luke133yt/Media-Archive',
        },
      ],
    };
  }

  String _description(MediaItem item) {
    final bits = <String>[
      '📦 ${item.format}',
      if (item.region.isNotEmpty) item.region,
      if (item.mediaLanguage.isNotEmpty) item.mediaLanguage,
      if (item.watched) 'Watched',
      if (item.archived) 'Archived',
      if (item.lostMedia) 'Lost media',
    ];
    final header = bits.join(' · ');
    if (item.overview.isEmpty) return header;
    return '$header\n\n${item.overview}';
  }

  Map<String, dynamic> _ownershipStream(MediaItem item) {
    final emoji = _formatEmoji(item.format);
    return {
      'name': '$emoji ${item.format}',
      'title':
          'In Media Archive · ${item.format}${item.region.isEmpty ? '' : ' · ${item.region}'}',
      'description':
          'Hai questo titolo in formato fisico. Non è uno stream digitale.',
      'behaviorHints': {
        'notWebReady': true,
        'bingeGroup': 'mediaarchive-owned',
      },
      'externalUrl': 'https://github.com/Luke133yt/Media-Archive',
    };
  }

  String _formatEmoji(String format) {
    final n = format.toLowerCase();
    if (n.contains('vhs') ||
        n.contains('beta') ||
        n.contains('video 2000') ||
        n.contains('hi8') ||
        n.contains('video8')) {
      return '📼';
    }
    if (n.contains('4k') || n.contains('uhd')) return '🟦';
    if (n.contains('blu')) return '💿';
    if (n.contains('dvd') || n.contains('hd-dvd') || n.contains('laser')) {
      return '📀';
    }
    if (n.contains('mm') || n.contains('super 8')) return '🎞️';
    return '📦';
  }

  Map<String, dynamic> _itemJson(MediaItem item) => {
        'id': item.id,
        'tmdbId': item.tmdbId,
        'type': item.type,
        'title': item.title,
        'originalTitle': item.originalTitle,
        'year': item.year,
        'format': item.format,
        'region': item.region,
        'posterPath': item.posterPath,
        'backdropPath': item.backdropPath,
        'overview': item.overview,
        'voteAverage': item.voteAverage,
        'genres': item.genres,
        'watched': item.watched,
        'addedAt': item.addedAt.toIso8601String(),
      };

  String _configureHtml(String manifest) => '''
<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Media Archive · Nuvio / Stremio</title>
  <style>
    body{font-family:system-ui,sans-serif;max-width:720px;margin:40px auto;padding:0 16px;background:#0f1220;color:#eef2ff}
    a{color:#9db7ff} code{background:#1b2140;padding:2px 6px;border-radius:6px}
    .card{background:#171b33;border-radius:16px;padding:20px;margin:16px 0}
    button{background:#6d86ff;color:white;border:0;border-radius:12px;padding:12px 16px;font-weight:700;cursor:pointer}
  </style>
</head>
<body>
  <h1>Media Archive addon</h1>
  <div class="card">
    <p>Manifest locale:</p>
    <p><code id="m">$manifest</code></p>
    <p>
      <button onclick="navigator.clipboard.writeText(document.getElementById('m').textContent)">Copia URL</button>
      <a href="stremio://$manifest"><button type="button">Installa in Stremio</button></a>
    </p>
    <p>Su <strong>Nuvio</strong>: Impostazioni → Addons → incolla l’URL del manifest.</p>
  </div>
  <div class="card">
    <p>Endpoint export live: <code>/export.json</code></p>
    <p>Per uso remoto carica un backup JSON su Google Drive (link diretto) e usa l’addon Node in <code>stremio_addon/</code>.</p>
  </div>
</body>
</html>
''';
}
