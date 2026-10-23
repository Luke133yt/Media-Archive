import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'formats.dart';
import 'models.dart';
import 'tmdb.dart';

class AppState extends ChangeNotifier {
  List<MediaItem> items = [];
  List<String> formats = List.of(defaultFormats);
  String apiKey = '';
  String tmdbLang = 'it-IT';
  String mediaLanguage = 'Italiano';
  bool reduceResources = false;
  bool darkTheme = true;

  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    apiKey = _p.getString('apiKey') ?? '';
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
    String? lang,
    String? mediaLang,
    bool? reduceResources,
    bool? darkTheme,
  }) {
    if (key != null) apiKey = key;
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

  /// Importa un elenco di elementi. Con [replace] sostituisce l'archivio,
  /// altrimenti unisce evitando duplicati (stesso id, oppure stesso
  /// titolo + anno + formato). Restituisce il numero di elementi aggiunti.
  int importItems(List<MediaItem> incoming,
      {List<String> extraFormats = const [], bool replace = false}) {
    if (replace) items = [];
    String key(MediaItem i) =>
        '${i.title.toLowerCase()}|${i.year ?? ''}|${i.format.toLowerCase()}';
    final ids = items.map((e) => e.id).toSet();
    final keys = items.map(key).toSet();
    var added = 0;
    for (final i in incoming) {
      if (ids.contains(i.id) || keys.contains(key(i))) continue;
      items.add(i);
      ids.add(i.id);
      keys.add(key(i));
      _ensureFormat(i.format);
      added++;
    }
    for (final f in extraFormats) {
      _ensureFormat(f);
    }
    _commit();
    return added;
  }

  void clearAll() {
    items = [];
    _commit();
  }
}
