import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'models.dart';

class ParsedImport {
  final List<MediaItem> items;
  final List<String> formats;
  final String source;
  final bool isNativeBackup;
  final bool isTmdbJson;

  ParsedImport(this.items, this.formats, this.source,
      {this.isNativeBackup = false, this.isTmdbJson = false});
}

class IoService {
  static String stamp() => DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

  // ---------- Salvataggio / apertura file ----------

  static Future<bool> saveText(
      String baseName, String ext, String content) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final fileName = '${baseName}_${stamp()}.$ext';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Salva file',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (path == null) return kIsWeb; // sul web il download parte comunque
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
      // su desktop il picker restituisce solo il percorso
      final out = path.toLowerCase().endsWith('.$ext') ? path : '$path.$ext';
      await File(out).writeAsBytes(bytes);
    }
    return true;
  }

  /// Restituisce (nome file, contenuto) oppure null se annullato.
  static Future<(String, String)?> pickText() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv', 'xml', 'txt'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) return null;
    return (f.name, utf8.decode(bytes, allowMalformed: true));
  }

  /// Seleziona un CSV senza importarlo nell'archivio persistente.
  static Future<(String, String)?> pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) return null;
    return (f.name, utf8.decode(bytes, allowMalformed: true));
  }

  // ---------- Export ----------

  static String toJson(Map<String, dynamic> map) =>
      const JsonEncoder.withIndent('  ').convert(map);

  static const _csvHeader = [
    'id',
    'tmdb_id',
    'type',
    'title',
    'original_title',
    'year',
    'format',
    'region',
    'language',
    'price',
    'barcode',
    'archived',
    'lost_media',
    'watched',
    'genres',
    'director',
    'runtime',
    'tmdb_rating',
    'my_rating_5',
    'quality_rating',
    'my_review',
    'loan_to',
    'loan_since',
    'notes',
    'overview',
  ];

  static String toCsv(List<MediaItem> items) {
    final rows = <List<dynamic>>[_csvHeader];
    for (final i in items) {
      rows.add([
        i.id,
        i.tmdbId ?? '',
        i.type,
        i.title,
        i.originalTitle,
        i.year ?? '',
        i.format,
        i.region,
        i.mediaLanguage,
        i.price ?? '',
        i.barcode,
        i.archived ? 1 : 0,
        i.lostMedia ? 1 : 0,
        i.watched ? 1 : 0,
        i.genres.join('; '),
        i.director ?? '',
        i.runtime ?? '',
        i.voteAverage ?? '',
        i.myRating ?? '',
        i.qualityRating ?? '',
        i.myReview,
        i.loan?.borrower ?? '',
        i.loan?.since.toIso8601String() ?? '',
        i.notes,
        i.overview,
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ---------- Import ----------

  static ParsedImport parseAny(String fileName, String content) {
    final name = fileName.toLowerCase();
    final trimmed = content.trimLeft();
    if (name.endsWith('.json') ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('[')) {
      return _parseJson(content);
    }
    if (name.endsWith('.xml') || trimmed.startsWith('<')) {
      return ParsedImport(_parseXml(content), [], 'XML');
    }
    return ParsedImport(_parseCsv(content), [], 'CSV');
  }

  static ParsedImport _parseJson(String content) {
    final data = jsonDecode(content);
    if (data is Map && data['items'] is List) {
      final records = (data['items'] as List).whereType<Map>().toList();
      if (records.isNotEmpty && records.every(_looksLikeTmdbRecord)) {
        return ParsedImport(
          records.map(_fromTmdbRecord).toList(),
          const ['Non Specificato'],
          'TMDB JSON',
          isTmdbJson: true,
        );
      }
      final items = (data['items'] as List)
          .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final formats =
          ((data['formats'] ?? []) as List).map((e) => e.toString()).toList();
      return ParsedImport(items, formats, 'Backup Media Archive',
          isNativeBackup: data['app'] == 'media_archive');
    }
    if (data is Map && data['results'] is List) {
      final records = (data['results'] as List).whereType<Map>().toList();
      if (records.isNotEmpty && records.every(_looksLikeTmdbRecord)) {
        return ParsedImport(
          records.map(_fromTmdbRecord).toList(),
          const ['Non Specificato'],
          'TMDB JSON',
          isTmdbJson: true,
        );
      }
    }
    if (data is Map && _looksLikeTmdbRecord(data)) {
      return ParsedImport(
        [_fromTmdbRecord(data)],
        const ['Non Specificato'],
        'TMDB JSON',
        isTmdbJson: true,
      );
    }
    if (data is List) {
      final tmdbRecords = data.whereType<Map>().toList();
      if (tmdbRecords.isNotEmpty &&
          tmdbRecords.length == data.length &&
          tmdbRecords.every(_looksLikeTmdbRecord)) {
        return ParsedImport(
          tmdbRecords.map(_fromTmdbRecord).toList(),
          const ['Non Specificato'],
          'TMDB JSON',
          isTmdbJson: true,
        );
      }
      final items = data.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        if (m.containsKey('title') && m.containsKey('format')) {
          return MediaItem.fromJson(m);
        }
        return _fromRecord(m.map((k, v) => MapEntry(k, v?.toString() ?? '')));
      }).toList();
      return ParsedImport(items, [], 'JSON');
    }
    throw const FormatException('Formato JSON non riconosciuto');
  }

  static bool _looksLikeTmdbRecord(Map<dynamic, dynamic> record) {
    final id = int.tryParse((record['id'] ?? '').toString());
    final mediaType =
        (record['media_type'] ?? record['type'] ?? '').toString().toLowerCase();
    if (mediaType.isNotEmpty && mediaType != 'movie' && mediaType != 'tv') {
      return false;
    }
    final hasTitle =
        (record['title'] ?? record['name'] ?? '').toString().trim().isNotEmpty;
    final hasTmdbFields = record.containsKey('poster_path') ||
        record.containsKey('media_type') ||
        record.containsKey('release_date') ||
        record.containsKey('first_air_date') ||
        record.containsKey('vote_average');
    return id != null && hasTitle && hasTmdbFields;
  }

  static MediaItem _fromTmdbRecord(Map<dynamic, dynamic> raw) {
    final record = Map<String, dynamic>.from(raw);
    final typeValue =
        (record['media_type'] ?? record['type'] ?? '').toString().toLowerCase();
    final tv = typeValue == 'tv' ||
        (typeValue.isEmpty && record['first_air_date'] != null);
    final genreData = record['genres'] ?? record['genre_ids'] ?? const [];
    final genres = genreData is List
        ? genreData
            .map((genre) => genre is Map
                ? (genre['name'] ?? '').toString()
                : genre is String
                    ? genre
                    : '')
            .where((genre) => genre.isNotEmpty)
            .toList()
        : <String>[];
    final credits = record['credits'];
    final castData = credits is Map ? credits['cast'] : null;
    final cast = castData is List
        ? castData
            .whereType<Map>()
            .map((person) => CastMember(
                  id: int.tryParse((person['id'] ?? '').toString()),
                  name: (person['name'] ?? '').toString(),
                  character: (person['character'] ?? '').toString(),
                  profilePath: person['profile_path']?.toString(),
                ))
            .toList()
        : <CastMember>[];
    final date =
        (tv ? record['first_air_date'] : record['release_date'])?.toString() ??
            '';
    final year = RegExp(r'^(\d{4})').firstMatch(date)?.group(1);

    return MediaItem(
      tmdbId: int.tryParse((record['id'] ?? '').toString()),
      type: tv ? 'tv' : 'movie',
      title: (record['title'] ?? record['name'] ?? '').toString(),
      originalTitle: (record['original_title'] ?? record['original_name'] ?? '')
          .toString(),
      year: year == null ? null : int.tryParse(year),
      overview: (record['overview'] ?? '').toString(),
      posterPath: record['poster_path']?.toString(),
      backdropPath: record['backdrop_path']?.toString(),
      genres: genres,
      runtime: int.tryParse((record['runtime'] ?? '').toString()),
      voteAverage: (record['vote_average'] as num?)?.toDouble(),
      budget: (record['budget'] as num?)?.toInt(),
      revenue: (record['revenue'] as num?)?.toInt(),
      seasons: (record['number_of_seasons'] as num?)?.toInt(),
      cast: cast,
      format: 'Non Specificato',
    );
  }

  static List<MediaItem> _parseCsv(String content) {
    // prova i separatori più comuni
    List<List<dynamic>> rows = [];
    var bestScore = -1;
    for (final sep in [',', ';', '\t', '|']) {
      final candidate = CsvToListConverter(
        fieldDelimiter: sep,
        shouldParseNumbers: false,
        eol: content.contains('\r\n') ? '\r\n' : '\n',
      ).convert(content);
      if (candidate.length < 2) continue;
      final normalizedHeader =
          candidate.first.map((e) => _norm(e.toString())).toList();
      const known = {
        'title',
        'titolo',
        'titulo',
        'name',
        'titre',
        'year',
        'anno',
        'ano',
        'format',
        'formato',
        'media',
        'support',
        'supporto',
        'type',
        'tipo',
        'barcode',
        'ean',
        'director',
        'regista',
        'notes',
        'note',
      };
      var score = normalizedHeader.where(known.contains).length;
      if (normalizedHeader
          .any({'title', 'titolo', 'titulo', 'name', 'titre'}.contains)) {
        score += 10;
      }
      if (normalizedHeader.contains('media')) score += 8;
      final width = candidate.first.length;
      if (width > 1 && candidate.skip(1).any((row) => row.length == width)) {
        score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        rows = candidate;
      }
    }
    if (rows.length < 2) return [];
    final header = rows.first.map((e) => e.toString()).toList();
    final out = <MediaItem>[];
    for (final r in rows.skip(1)) {
      if (r.every((c) => c.toString().trim().isEmpty)) continue;
      final rec = <String, String>{};
      for (var c = 0; c < header.length && c < r.length; c++) {
        rec[header[c]] = r[c].toString();
      }
      out.add(_fromRecord(rec));
    }
    return out;
  }

  static List<MediaItem> _parseXml(String content) {
    final doc = XmlDocument.parse(content);
    var cur = doc.rootElement;
    List<XmlElement> records = [];
    while (true) {
      final ch = cur.childElements.toList();
      if (ch.isEmpty) break;
      final nested = ch.every((e) => e.childElements.isNotEmpty);
      if (nested && ch.length > 1) {
        records = ch;
        break;
      }
      if (ch.length == 1 && ch.first.childElements.isNotEmpty) {
        cur = ch.first;
        continue;
      }
      records = [cur];
      break;
    }
    final out = <MediaItem>[];
    for (final e in records) {
      final rec = <String, String>{};
      for (final a in e.attributes) {
        rec[a.name.local] = a.value;
      }
      for (final c in e.childElements) {
        rec[c.name.local] = c.innerText.trim();
      }
      final item = _fromRecord(rec);
      if (item.title.isNotEmpty) out.add(item);
    }
    return out;
  }

  // ---------- Mappatura campi (tollera nomi in IT/EN/ES) ----------

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _pick(Map<String, String> rec, List<String> keys) {
    for (final k in keys) {
      final v = rec[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static MediaItem _fromRecord(Map<String, String> raw) {
    final rec = {for (final e in raw.entries) _norm(e.key): e.value};

    final title = _pick(rec, [
          'title',
          'titolo',
          'titulo',
          'titulocastellano',
          'titulotraducido',
          'titolotradotto',
          'nome',
          'name',
          'titre',
        ]) ??
        '';
    final original = _pick(rec, [
          'originaltitle',
          'titolooriginale',
          'tituloriginal',
          'titulooriginal',
          'originaltitel',
        ]) ??
        '';
    final yearStr = _pick(rec, [
      'year',
      'anno',
      'ano',
      'ao',
      'fecha',
      'releasedate',
      'datauscita',
    ]);
    int? year;
    if (yearStr != null) {
      final m = RegExp(r'(19|20)\d{2}').firstMatch(yearStr);
      if (m != null) year = int.tryParse(m.group(0)!);
    }
    final typeStr =
        (_pick(rec, ['type', 'tipo', 'mediatype']) ?? '').toLowerCase();
    final isTv = typeStr.contains('tv') ||
        typeStr.contains('serie') ||
        typeStr.contains('show') ||
        typeStr.contains('temporada');
    final explicitFormat = _pick(rec, [
      'format',
      'formato',
      'supporto',
      'mediaformat',
      'formatname',
      'physicalformat',
      'carrier',
      'medium',
      'material',
      'supporttype',
      'support',
      'soporte',
      'media',
      'mediasupport',
      'tipoformato',
    ]);
    final typeAsFormat =
        RegExp(r'^(movie|film|cinema|tv|serie|series|show)$').hasMatch(typeStr)
            ? null
            : _pick(rec, ['tipo', 'type']);

    final priceStr = _pick(rec, ['price', 'prezzo', 'precio', 'prix']);
    double? price;
    if (priceStr != null) {
      price = double.tryParse(
          priceStr.replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '.'));
    }

    final archivedStr =
        (_pick(rec, ['archived', 'archiviato', 'archivado']) ?? '')
            .toLowerCase();
    final archived =
        ['1', 'true', 'si', 'sì', 'yes', 'x', 'y'].contains(archivedStr);
    final watchedStr =
        (_pick(rec, ['watched', 'visto', 'visionato']) ?? '').toLowerCase();
    final watched =
        ['1', 'true', 'si', 'sì', 'yes', 'x', 'y'].contains(watchedStr);
    final lostMediaStr =
        (_pick(rec, ['lostmedia', 'lost_media', 'lost', 'perso', 'lostfilm']) ??
                '')
            .toLowerCase();
    final lostMedia =
        ['1', 'true', 'si', 'sì', 'yes', 'x', 'y'].contains(lostMediaStr);
    final currentRating = _pick(rec, ['myrating5', 'myrating_5']);
    final legacyRating = _pick(rec, ['myrating', 'miovoto', 'micalificacion']);
    final ratingValue = double.tryParse(
        (currentRating ?? legacyRating ?? '').replaceAll(',', '.'));

    final loanTo = _pick(rec, [
      'loanto',
      'prestatoa',
      'prestadoa',
      'prestado',
      'borrower',
      'prestito',
    ]);
    final loanSince = _pick(rec, ['loansince', 'prestatodal', 'fechaprestamo']);

    return MediaItem(
      id: _pick(rec, ['id']),
      tmdbId: int.tryParse(_pick(rec, ['tmdbid']) ?? ''),
      type: isTv ? 'tv' : 'movie',
      title: title,
      originalTitle: original,
      year: year,
      overview: _pick(rec, [
            'overview',
            'sinossi',
            'sinopsis',
            'argumento',
            'trama',
            'description',
            'descrizione',
            'synopsis',
          ]) ??
          '',
      genres:
          (_pick(rec, ['genres', 'genre', 'genere', 'genero', 'genres']) ?? '')
              .split(RegExp(r'[;,/|]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      director: _pick(rec, ['director', 'regista', 'regia', 'realisateur']),
      runtime: int.tryParse(
          (_pick(rec, ['runtime', 'durata', 'duracion', 'minutos']) ?? '')
              .replaceAll(RegExp(r'[^0-9]'), '')),
      voteAverage: double.tryParse(_pick(rec, ['tmdbrating']) ?? ''),
      format: explicitFormat?.trim().isNotEmpty == true
          ? explicitFormat!.trim()
          : typeAsFormat?.trim().isNotEmpty == true
              ? typeAsFormat!.trim()
              : 'Non Specificato',
      region: _pick(rec, ['region', 'regione', 'zona', 'zone']) ?? '',
      mediaLanguage:
          _pick(rec, ['language', 'lingua', 'idioma', 'langue']) ?? '',
      price: price,
      barcode: _pick(rec, ['barcode', 'ean', 'upc', 'codigodebarras']) ?? '',
      archived: archived,
      lostMedia: lostMedia,
      watched: watched,
      notes: _pick(rec, ['notes', 'note', 'notas', 'comentarios']) ?? '',
      myRating: currentRating != null
          ? ratingValue
          : (ratingValue == null ? null : ratingValue / 2),
      qualityRating: double.tryParse(
          (_pick(rec, ['qualityrating', 'qualityrating5', 'votoqualita']) ?? '')
              .replaceAll(',', '.')),
      myReview: _pick(rec, ['myreview', 'miarecensione']) ?? '',
      loan: loanTo == null
          ? null
          : LoanInfo(
              borrower: loanTo,
              since: DateTime.tryParse(loanSince ?? '') ?? DateTime.now(),
            ),
    );
  }
}
