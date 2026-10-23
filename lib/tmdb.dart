import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class TmdbException implements Exception {
  final String message;
  TmdbException(this.message);
  @override
  String toString() => message;
}

/// Client TMDB. Accetta sia la "API Key" (v3) sia il
/// "Read Access Token" (v4, lungo, JWT).
class TmdbClient {
  final String key;
  final String lang;
  TmdbClient(this.key, this.lang);

  static const _base = 'https://api.themoviedb.org/3';

  bool get _isBearer => key.length > 60;

  Map<String, String> get _headers => {
        'accept': 'application/json',
        if (_isBearer) 'Authorization': 'Bearer $key',
      };

  Uri _uri(String path, [Map<String, String>? q, String? language]) {
    final params = <String, String>{
      'language': language ?? lang,
      if (!_isBearer) 'api_key': key,
      ...?q,
    };
    return Uri.parse('$_base$path').replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? q, String? language]) async {
    final res = await http.get(_uri(path, q, language), headers: _headers);
    if (res.statusCode == 401) {
      throw TmdbException('Chiave TMDB non valida (401).');
    }
    if (res.statusCode != 200) {
      throw TmdbException('Errore TMDB (${res.statusCode}).');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  static String img(String? path, {String size = 'w342'}) {
    if (path == null || path.trim().isEmpty) return '';
    final value = path.trim();
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    return 'https://image.tmdb.org/t/p/$size${value.startsWith('/') ? value : '/$value'}';
  }

  static int? _year(dynamic date) {
    final s = (date ?? '').toString();
    if (s.length < 4) return null;
    return int.tryParse(s.substring(0, 4));
  }

  Future<void> test() async {
    await _get('/configuration');
  }

  Future<List<TmdbResult>> search(String query, {String? language}) async {
    final j = await _get(
        '/search/multi',
        {
          'query': query,
          'include_adult': 'false',
        },
        language);
    final out = <TmdbResult>[];
    for (final r in (j['results'] as List? ?? [])) {
      final type = r['media_type'];
      if (type != 'movie' && type != 'tv') continue;
      out.add(TmdbResult(
        id: r['id'] as int,
        type: type as String,
        title: (type == 'movie' ? r['title'] : r['name'])?.toString() ?? '',
        originalTitle:
            (type == 'movie' ? r['original_title'] : r['original_name'])
                    ?.toString() ??
                '',
        year: _year(type == 'movie' ? r['release_date'] : r['first_air_date']),
        posterPath: r['poster_path'] as String?,
        overview: (r['overview'] ?? '').toString(),
      ));
    }
    return out;
  }

  Future<MediaItem> details(int id, String type) async {
    final j = await _get('/$type/$id', {'append_to_response': 'credits'});
    final isMovie = type == 'movie';

    final credits = (j['credits'] as Map?) ?? {};
    final cast = ((credits['cast'] as List?) ?? [])
        .take(20)
        .map((c) => CastMember(
              id: (c['id'] as num?)?.toInt(),
              name: (c['name'] ?? '').toString(),
              character: (c['character'] ?? '').toString(),
              profilePath: c['profile_path'] as String?,
            ))
        .toList();

    String? director;
    if (isMovie) {
      for (final c in ((credits['crew'] as List?) ?? [])) {
        if (c['job'] == 'Director') {
          director = c['name']?.toString();
          break;
        }
      }
    } else {
      final cb = (j['created_by'] as List?) ?? [];
      if (cb.isNotEmpty) {
        director = cb.map((e) => e['name']).join(', ');
      }
    }

    int? runtime;
    if (isMovie) {
      runtime = (j['runtime'] as num?)?.toInt();
    } else {
      final er = (j['episode_run_time'] as List?) ?? [];
      if (er.isNotEmpty) runtime = (er.first as num).toInt();
    }

    // Le recensioni TMDB sono quasi tutte in inglese
    final reviews = <TmdbReview>[];
    try {
      final r = await _get('/$type/$id/reviews', {'language': 'en-US'});
      for (final x in ((r['results'] as List?) ?? []).take(5)) {
        var text = (x['content'] ?? '').toString().trim();
        if (text.length > 700) text = '${text.substring(0, 700)}…';
        reviews.add(TmdbReview(
          author: (x['author'] ?? '').toString(),
          content: text,
          rating: ((x['author_details'] ?? {})['rating'] as num?)?.toDouble(),
        ));
      }
    } catch (_) {}

    final budget = (j['budget'] as num?)?.toInt();
    final revenue = (j['revenue'] as num?)?.toInt();

    return MediaItem(
      tmdbId: id,
      type: type,
      title: (isMovie ? j['title'] : j['name'])?.toString() ?? '',
      originalTitle:
          (isMovie ? j['original_title'] : j['original_name'])?.toString() ??
              '',
      year: _year(isMovie ? j['release_date'] : j['first_air_date']),
      overview: (j['overview'] ?? '').toString(),
      tagline: (j['tagline'] ?? '').toString(),
      posterPath: j['poster_path'] as String?,
      backdropPath: j['backdrop_path'] as String?,
      genres: ((j['genres'] as List?) ?? [])
          .map((g) => g['name'].toString())
          .toList(),
      runtime: runtime,
      voteAverage: (j['vote_average'] as num?)?.toDouble(),
      budget: (budget ?? 0) > 0 ? budget : null,
      revenue: (revenue ?? 0) > 0 ? revenue : null,
      seasons: (j['number_of_seasons'] as num?)?.toInt(),
      director: director,
      cast: cast,
      reviews: reviews,
    );
  }

  Future<PersonDetails> personDetails(int id) async {
    final j =
        await _get('/person/$id', {'append_to_response': 'combined_credits'});
    final creditsJson = (j['combined_credits'] as Map?) ?? const {};
    final credits = <PersonCredit>[];
    final seen = <String>{};
    for (final category in ['cast', 'crew']) {
      for (final c in (creditsJson[category] as List? ?? const [])) {
        final type = (c['media_type'] ?? '').toString();
        if (type != 'movie' && type != 'tv') continue;
        final itemId = (c['id'] as num?)?.toInt();
        if (itemId == null || !seen.add('$type:$itemId')) continue;
        credits.add(PersonCredit(
          id: itemId,
          type: type,
          title: (type == 'movie' ? c['title'] : c['name'])?.toString() ?? '',
          date: (type == 'movie' ? c['release_date'] : c['first_air_date'])
              ?.toString(),
          posterPath: c['poster_path'] as String?,
          role: (category == 'cast' ? c['character'] : c['job'])?.toString() ??
              '',
          voteAverage: (c['vote_average'] as num?)?.toDouble(),
        ));
      }
    }
    credits.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    return PersonDetails(
      id: id,
      name: (j['name'] ?? '').toString(),
      biography: (j['biography'] ?? '').toString(),
      birthday: j['birthday'] as String?,
      deathday: j['deathday'] as String?,
      placeOfBirth: j['place_of_birth'] as String?,
      profilePath: j['profile_path'] as String?,
      knownForDepartment: (j['known_for_department'] ?? '').toString(),
      credits: credits,
    );
  }

  Future<int?> searchPersonId(String query) async {
    final j = await _get('/search/person', {'query': query});
    final results = (j['results'] as List? ?? const []);
    if (results.isEmpty) return null;
    return (results.first['id'] as num?)?.toInt();
  }

  Future<List<String>> mediaImages(int id, String type) async {
    if (type != 'movie' && type != 'tv') return const [];
    final languageCode = lang.split(RegExp(r'[-_]')).first;
    final j = await _get('/$type/$id/images', {
      'include_image_language': '$languageCode,en,it,null',
    });
    final paths = <String>[];
    for (final category in ['posters', 'backdrops']) {
      for (final image in (j[category] as List? ?? const [])) {
        final path = (image['file_path'] ?? '').toString();
        if (path.isNotEmpty && !paths.contains(path)) paths.add(path);
      }
    }
    return paths;
  }
}

/// Cerca il titolo associato a un codice a barre (EAN/UPC) tramite UPCitemdb
/// (endpoint gratuito con limiti giornalieri). Restituisce null se non trovato.
/// Nota: sul web può essere bloccato da CORS.
Future<String?> lookupBarcodeTitle(String code) async {
  try {
    final res = await http.get(Uri.parse(
        'https://api.upcitemdb.com/prod/trial/lookup?upc=${Uri.encodeComponent(code)}'));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (j['items'] as List?) ?? [];
    if (items.isEmpty) return null;
    var title = (items.first['title'] ?? '').toString();
    // toglie sigle di formato e rumore comune
    title = title
        .replaceAll(
            RegExp(
                r'\b(blu-?ray|4k|uhd|ultra hd|dvd|hd-?dvd|vhs|region \w+|widescreen|special edition|steelbook|\d+-?disc)\b',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ')
        .replaceAll(RegExp(r'[-:/|]+\s*$'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return title.isEmpty ? null : title;
  } catch (_) {
    return null;
  }
}
