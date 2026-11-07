import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'formats.dart';
import 'localization.dart';
import 'models.dart';
import 'tmdb.dart';

class ImportResult {
  final int added;
  final int duplicates;

  const ImportResult({required this.added, required this.duplicates});
}

class AppState extends ChangeNotifier {
  List<MediaItem> items = [];
  List<String> formats = List.of(defaultFormats);
  String apiKey = '';
  String appLanguage = 'en';
  String tmdbLang = 'it-IT';
  String mediaLanguage = 'Italiano';
  bool reduceResources = false;
  bool darkTheme = true;

  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    apiKey = _p.getString('apiKey') ?? '';
    appLanguage = _p.getString('appLanguage') ?? 'en';
    AppStrings.language = appLanguage;
    reduceResources = _p.getBool('reduceResources') ?? false;
    darkTheme = _p.getBool('darkTheme') ?? true;

    final sysCode = ui.PlatformDispatcher.instance.locale.languageCode;
    tmdbLang = _p.getString('tmdbLang') ?? _defaultTmdbLang(sysCode);
    mediaLanguage =
        _p.getString('mediaLanguage') ?? languageNameFromCode(sysCode);

    final f = _p.getStringList('formats');
    if (f != null && f.isNotEmpty) formats = f;

    final raw = _p.getString('items');
    if (raw != null) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Errore lettura archivio: $e');
      }
    }
  }

  String _defaultTmdbLang(String code) {
    const m = {
      'it': 'it-IT',
      'en': 'en-US',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'es': 'es-ES',
      'pt': 'pt-BR',
      'ja': 'ja-JP',
    };
    return m[code] ?? 'en-US';
  }

  Future<void> _save() async {
    await _p.setString(
        'items', jsonEncode(items.map((e) => e.toJson()).toList()));
    await _p.setStringList('formats', formats);
    await _p.setString('apiKey', apiKey);
    await _p.setString('appLanguage', appLanguage);
    await _p.setString('tmdbLang', tmdbLang);
    await _p.setString('mediaLanguage', mediaLanguage);
    await _p.setBool('reduceResources', reduceResources);
    await _p.setBool('darkTheme', darkTheme);
  }

  void _commit() {
    notifyListeners();
    _save();
  }

  TmdbClient? get tmdb =>
      apiKey.trim().isEmpty ? null : TmdbClient(apiKey.trim(), tmdbLang);

  MediaItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  void upsert(MediaItem item) {
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    _ensureFormat(item.format);
    _commit();
  }

  Future<void> saveLoan(String id, LoanInfo? loan) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    items[index] = items[index].clone()..loan = loan;
    notifyListeners();
    await _save();
  }

  void remove(String id) {
    items.removeWhere((e) => e.id == id);
    _commit();
  }

  void _ensureFormat(String f) {
    final t = f.trim();
    if (t.isEmpty) return;
    if (!formats.any((e) => e.toLowerCase() == t.toLowerCase())) {
      formats.add(t);
    }
  }

  void addFormat(String f) {
    _ensureFormat(f);
    _commit();
  }

  void removeFormat(String f) {
    formats.remove(f);
    _commit();
  }

  void updateSettings({
    String? key,
    String? appLanguage,
    String? lang,
    String? mediaLang,
    bool? reduceResources,
    bool? darkTheme,
  }) {
    if (key != null) apiKey = key;
    if (appLanguage != null) {
      this.appLanguage = appLanguage;
      AppStrings.language = appLanguage;
    }
    if (lang != null) tmdbLang = lang;
    if (mediaLang != null) mediaLanguage = mediaLang;
    if (reduceResources != null) this.reduceResources = reduceResources;
    if (darkTheme != null) this.darkTheme = darkTheme;
    _commit();
  }

  // ---------- Backup / import ----------

  Map<String, dynamic> exportMap() => {
        'app': 'media_archive',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'formats': formats,
        'items': items.map((e) => e.toJson()).toList(),
      };

  /// Importa un elenco di elementi. Con [replace] sostituisce l'archivio;
  /// normalmente l'unione salta duplicati per ID TMDB o dati del titolo.
  /// [allowDuplicates] conserva invece tutti gli elementi del file importato.
  ImportResult importItems(List<MediaItem> incoming,
      {List<String> extraFormats = const [],
      bool replace = false,
      bool allowDuplicates = false}) {
    if (replace) items = [];
    String normalize(String value) {
      var result = value.trim().toLowerCase();
      const accents = {
        'à': 'a',
        'á': 'a',
        'â': 'a',
        'ä': 'a',
        'ã': 'a',
        'å': 'a',
        'è': 'e',
        'é': 'e',
        'ê': 'e',
        'ë': 'e',
        'ì': 'i',
        'í': 'i',
        'î': 'i',
        'ï': 'i',
        'ò': 'o',
        'ó': 'o',
        'ô': 'o',
        'ö': 'o',
        'õ': 'o',
        'ù': 'u',
        'ú': 'u',
        'û': 'u',
        'ü': 'u',
        'ç': 'c',
        'ñ': 'n',
      };
      for (final entry in accents.entries) {
        result = result.replaceAll(entry.key, entry.value);
      }
      return String.fromCharCodes(result.runes.where((rune) =>
          rune > 127 ||
          (rune >= 48 && rune <= 57) ||
          (rune >= 97 && rune <= 122)));
    }

    Set<String> titleKeys(MediaItem item) {
      final year = item.year?.toString() ?? '';
      final keys = <String>{};
      for (final title in {item.title, item.originalTitle}) {
        final normalizedTitle = normalize(title);
        if (normalizedTitle.isEmpty) continue;
        keys.add('title:${item.type}:$normalizedTitle|$year');
      }
      return keys;
    }

    String formatKey(MediaItem item) => normalize(item.format);
    bool isUnspecified(MediaItem item) =>
        formatKey(item) == normalize('Non Specificato');
    Set<String> duplicateKeys(MediaItem item) => {
          if (item.tmdbId != null) 'tmdb:${item.type}:${item.tmdbId}',
          for (final title in titleKeys(item)) '$title|${formatKey(item)}',
        };

    final ids = items.map((item) => item.id).toSet();
    final keys = <String>{for (final item in items) ...duplicateKeys(item)};
    final byTitle = <String, List<MediaItem>>{};
    for (final item in items) {
      for (final title in titleKeys(item)) {
        byTitle.putIfAbsent(title, () => []).add(item);
      }
    }
    var added = 0;
    var duplicates = 0;
    for (final original in incoming) {
      // Re-importing a backup may repeat its internal UUID. Give that copy a
      // fresh local ID so both records remain independently editable.
      final i = allowDuplicates && ids.contains(original.id)
          ? MediaItem.fromJson(original.toJson()..['id'] = null)
          : original;
      final incomingKeys = duplicateKeys(i);
      final hasUnspecifiedFormatMatch = titleKeys(i).any((title) =>
          (isUnspecified(i) && byTitle.containsKey(title)) ||
          (byTitle[title]?.any(isUnspecified) ?? false));
      if (!allowDuplicates &&
          (ids.contains(i.id) ||
              incomingKeys.any(keys.contains) ||
              hasUnspecifiedFormatMatch)) {
        duplicates++;
        continue;
      }
      items.add(i);
      ids.add(i.id);
      keys.addAll(incomingKeys);
      for (final title in titleKeys(i)) {
        byTitle.putIfAbsent(title, () => []).add(i);
      }
      _ensureFormat(i.format);
      added++;
    }
    for (final f in extraFormats) {
      _ensureFormat(f);
    }
    _commit();
    return ImportResult(added: added, duplicates: duplicates);
  }

  void clearAll() {
    items = [];
    _commit();
  }
}
