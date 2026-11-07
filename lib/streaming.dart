import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'tmdb.dart';

/// Destinazione streaming cliccabile (app o sito).
class StreamingTarget {
  final String id;
  final String label;
  final Uri uri;
  final String? logoUrl;
  final bool alwaysAvailable;

  const StreamingTarget({
    required this.id,
    required this.label,
    required this.uri,
    this.logoUrl,
    this.alwaysAvailable = false,
  });
}

class StreamingLinks {
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Uri? youtubeTrailer(List<TmdbVideo> videos) {
    for (final v in videos) {
      if (v.isYoutubeTrailer) return Uri.parse(v.youtubeUrl);
    }
    for (final v in videos) {
      if (v.site.toLowerCase() == 'youtube') {
        return Uri.parse(v.youtubeUrl);
      }
    }
    return null;
  }

  static List<StreamingTarget> buildTargets({
    required String title,
    required String type,
    required int? tmdbId,
    String? imdbId,
    WatchProvidersResult? providers,
    Uri? trailerUri,
  }) {
    final encoded = Uri.encodeComponent(title);
    final stremioType = type == 'tv' ? 'series' : 'movie';
    final stremioId = imdbId?.isNotEmpty == true
        ? imdbId!
        : (tmdbId == null ? null : 'tmdb:$tmdbId');
    final targets = <StreamingTarget>[
      StreamingTarget(
        id: 'nuvio',
        label: 'Nuvio',
        alwaysAvailable: true,
        // Nuvio non espone uno schema pubblico stabile: apriamo la scheda titolo
        // (IMDb/TMDB) così resta banale cercarlo nell’app con gli addon installati.
        uri: Uri.parse(
          imdbId != null && imdbId.isNotEmpty
              ? 'https://www.imdb.com/title/$imdbId/'
              : (tmdbId == null
                  ? 'https://nuvio.wiki/integrations/addons'
                  : 'https://www.themoviedb.org/${type == 'tv' ? 'tv' : 'movie'}/$tmdbId'),
        ),
      ),
      StreamingTarget(
        id: 'stremio',
        label: 'Stremio',
        alwaysAvailable: true,
        uri: Uri.parse(
          stremioId == null
              ? 'https://www.stremio.com/downloads'
              : 'stremio:///detail/$stremioType/$stremioId',
        ),
      ),
    ];

    if (trailerUri != null) {
      targets.add(StreamingTarget(
        id: 'youtube-trailer',
        label: 'YouTube (trailer)',
        uri: trailerUri,
        alwaysAvailable: true,
      ));
    }

    final known = <String, Uri Function(String)>{
      'netflix': (q) => Uri.parse('https://www.netflix.com/search?q=$q'),
      'amazon prime video': (q) =>
          Uri.parse('https://www.primevideo.com/search?phrase=$q'),
      'amazon video': (q) =>
          Uri.parse('https://www.primevideo.com/search?phrase=$q'),
      'disney plus': (q) =>
          Uri.parse('https://www.disneyplus.com/search?q=$q'),
      'disney+': (q) => Uri.parse('https://www.disneyplus.com/search?q=$q'),
      'apple tv': (q) => Uri.parse('https://tv.apple.com/search?term=$q'),
      'apple tv plus': (q) => Uri.parse('https://tv.apple.com/search?term=$q'),
      'paramount plus': (q) =>
          Uri.parse('https://www.paramountplus.com/search/?q=$q'),
      'paramount+': (q) =>
          Uri.parse('https://www.paramountplus.com/search/?q=$q'),
      'hulu': (q) => Uri.parse('https://www.hulu.com/search?q=$q'),
      'max': (q) => Uri.parse('https://www.max.com/search?q=$q'),
      'hbo max': (q) => Uri.parse('https://www.max.com/search?q=$q'),
      'now': (q) => Uri.parse('https://www.nowtv.com/search?q=$q'),
      'rakuten tv': (q) => Uri.parse('https://www.rakuten.tv/it/search?q=$q'),
      'chili': (q) => Uri.parse('https://it.chili.com/search?q=$q'),
      'youtube': (q) => Uri.parse(
          'https://www.youtube.com/results?search_query=$q+full+movie'),
      'google play movies': (q) => Uri.parse(
          'https://play.google.com/store/search?q=$q&c=movies'),
      'microsoft store': (q) => Uri.parse(
          'https://www.microsoft.com/store/search/movies?q=$q'),
    };

    final seen = <String>{'nuvio', 'stremio', 'youtube-trailer'};
    if (providers != null) {
      for (final p in providers.providers) {
        final key = p.name.toLowerCase().trim();
        final id = 'provider-${p.id}';
        if (!seen.add(id)) continue;
        final builder = known[key];
        final logo =
            p.logoPath == null ? null : TmdbClient.img(p.logoPath, size: 'w92');
        if (builder != null) {
          targets.add(StreamingTarget(
            id: id,
            label: p.name,
            uri: builder(encoded),
            logoUrl: logo,
          ));
        } else if (providers.justWatchUrl != null) {
          targets.add(StreamingTarget(
            id: id,
            label: p.name,
            uri: Uri.parse(providers.justWatchUrl!),
            logoUrl: logo,
          ));
        }
      }
      if (providers.justWatchUrl != null &&
          providers.providers.isNotEmpty &&
          seen.add('justwatch')) {
        targets.add(StreamingTarget(
          id: 'justwatch',
          label: 'JustWatch',
          uri: Uri.parse(providers.justWatchUrl!),
        ));
      }
    }

    // Fallback utili anche senza dati JustWatch.
    for (final entry in {
      'YouTube': known['youtube']!(encoded),
      'Netflix': known['netflix']!(encoded),
      'Amazon Prime Video': known['amazon prime video']!(encoded),
      'Disney+': known['disney plus']!(encoded),
    }.entries) {
      final id = 'fallback-${entry.key.toLowerCase().replaceAll(' ', '-')}';
      if (seen.add(id)) {
        targets.add(StreamingTarget(
          id: id,
          label: entry.key,
          uri: entry.value,
        ));
      }
    }

    return targets;
  }
}
