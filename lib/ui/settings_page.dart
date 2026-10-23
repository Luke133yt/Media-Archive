import 'package:flutter/material.dart';
import 'app_snack.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../formats.dart';
import '../io_service.dart';
import '../models.dart';
import '../store.dart';
import '../tmdb.dart';
import '../update_service.dart';
import 'format_icon.dart';
import 'glass.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _key;
  late final TextEditingController _mediaLang;
  final _newFormat = TextEditingController();
  bool _testing = false;
  List<MediaItem> _unmatched = [];
  bool _matching = false;
  bool _checkingUpdates = false;

  static const _langs = {
    'it-IT': 'Italiano',
    'en-US': 'English',
    'fr-FR': 'Français',
    'de-DE': 'Deutsch',
    'es-ES': 'Español',
    'pt-BR': 'Português (BR)',
    'ja-JP': '日本語',
  };

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _key = TextEditingController(text: s.apiKey);
    _mediaLang = TextEditingController(text: s.mediaLanguage);
  }

  @override
  void dispose() {
    _key.dispose();
    _mediaLang.dispose();
    _newFormat.dispose();
    super.dispose();
  }

  void _snack(String t) => showAppSnack(context, t);

  Future<void> _checkUpdates() async {
    setState(() => _checkingUpdates = true);
    await UpdateService.checkAndPrompt(context, showUpToDate: true);
    if (mounted) setState(() => _checkingUpdates = false);
  }

  Future<void> _openCreatorLink() async {
    final opened = await launchUrl(
      Uri.parse('https://beacons.ai/luke133'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _snack('Impossibile aprire il link.');
  }

  Future<void> _saveKey() async {
    final s = context.read<AppState>();
    s.updateSettings(key: _key.text.trim());
    final tmdb = s.tmdb;
    if (tmdb == null) {
      _snack('Chiave rimossa');
      return;
    }
    setState(() => _testing = true);
    try {
      await tmdb.test();
      _snack('Chiave TMDB valida ✔');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _exportJson() async {
    final s = context.read<AppState>();
    final ok = await IoService.saveText(
        'media_archive_backup', 'json', IoService.toJson(s.exportMap()));
    if (ok) _snack('Backup salvato');
  }

  Future<void> _exportCsv() async {
    final s = context.read<AppState>();
    final ok = await IoService.saveText(
        'media_archive_export', 'csv', IoService.toCsv(s.items));
    if (ok) _snack('CSV esportato');
  }

  Future<void> _import() async {
    final s = context.read<AppState>();
    try {
      final picked = await IoService.pickText();
      if (picked == null) return;
      final parsed = IoService.parseAny(picked.$1, picked.$2);
      if (parsed.items.isEmpty) {
        _snack('Nessun titolo trovato nel file.');
        return;
      }
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Importare ${parsed.items.length} titoli?'),
          content: Text('Origine rilevata: ${parsed.source}.\n\n'
              'Puoi unirli alla collezione attuale (i duplicati vengono saltati) '
              'oppure sostituirla del tutto.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: const Text('Sostituisci')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'merge'),
                child: const Text('Unisci')),
          ],
        ),
      );
      if (mode == null) return;
      final searchTmdb = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Collegare i titoli a TMDB?'),
          content: const Text(
              'Puoi cercare i corrispondenti su TMDB e importare i dati arricchiti, oppure importare direttamente i dati del file senza cercare corrispondenze.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Importa senza TMDB')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.search),
                label: const Text('Cerca su TMDB')),
          ],
        ),
      );
      if (searchTmdb == null) return;
      if (searchTmdb && s.tmdb == null) {
        _snack(
            'Configura prima la chiave TMDB oppure scegli l’import senza TMDB.');
        return;
      }
      final formatMap = await _resolveImportedFormats(parsed.items, s.formats);
      if (formatMap == null) return;
      for (final item in parsed.items) {
        item.format = formatMap[item.format] ?? item.format;
      }
      final tmdb = s.tmdb;
      final matched = <MediaItem>[];
      final unmatched = <MediaItem>[];
      if (searchTmdb) {
        final client = tmdb!;
        setState(() => _matching = true);
        for (final source in parsed.items) {
          if (source.tmdbId != null) {
            matched.add(source);
            continue;
          }
          try {
            final norm = (String x) =>
                x.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            final results =
                await _searchAcrossLanguages(client, source.title, s.tmdbLang);
            final candidates = results
                .where((r) =>
                    (norm(r.title) == norm(source.title) ||
                        norm(r.originalTitle) == norm(source.title)) &&
                    (source.year == null ||
                        r.year == null ||
                        source.year == r.year))
                .toList();
            if (candidates.length == 1) {
              final fresh = await client.details(
                  candidates.single.id, candidates.single.type);
              fresh
                ..format = source.format
                ..region = source.region
                ..mediaLanguage = source.mediaLanguage
                ..price = source.price
                ..barcode = source.barcode
                ..archived = source.archived
                ..lostMedia = source.lostMedia
                ..watched = source.watched
                ..notes = source.notes
                ..myRating = source.myRating
                ..qualityRating = source.qualityRating
                ..myReview = source.myReview
                ..loan = source.loan;
              matched.add(fresh);
            } else {
              unmatched.add(source);
            }
          } catch (_) {
            unmatched.add(source);
          }
        }
        if (mounted) setState(() => _matching = false);
      }
      final toImport = searchTmdb ? matched : parsed.items;
      final added = s.importItems(toImport,
          extraFormats: parsed.formats
              .map((f) => formatMap[f.toLowerCase()] ?? f)
              .toList(),
          replace: mode == 'replace');
      if (mounted) setState(() => _unmatched = unmatched);
      _snack(searchTmdb
          ? 'Importati $added titoli. ${unmatched.length} senza corrispondenza TMDB.'
          : 'Importati $added titoli senza collegamento TMDB.');
    } catch (e) {
      _snack('Import non riuscito: $e');
    }
  }

  Future<List<TmdbResult>> _searchAcrossLanguages(
      TmdbClient tmdb, String query, String primaryLanguage) async {
    final norm =
        (String x) => x.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final byId = <String, TmdbResult>{};
    for (final language in {primaryLanguage, 'it-IT'}) {
      final localized = await tmdb.search(query, language: language);
      for (final result in localized) {
        final key = '${result.type}:${result.id}';
        final previous = byId[key];
        if (previous == null ||
            ((norm(result.title) == norm(query) ||
                    norm(result.originalTitle) == norm(query)) &&
                norm(previous.title) != norm(query) &&
                norm(previous.originalTitle) != norm(query))) {
          byId[key] = result;
        }
      }
    }
    return byId.values.toList();
  }

  Future<Map<String, String>?> _resolveImportedFormats(
      List<MediaItem> items, List<String> existingFormats) async {
    final choices = {...defaultFormats, ...existingFormats}.toList();
    final groups = <String, String>{};
    for (final item in items) {
      final raw = item.format.trim();
      final key = raw.toLowerCase();
      if (key.isEmpty || groups.containsKey(key)) continue;
      final canonical = choices.cast<String?>().firstWhere(
            (f) => f!.toLowerCase() == key,
            orElse: () => null,
          );
      if (canonical != null) {
        groups[key] = canonical;
        continue;
      }
      final guessed = _guessFormat(raw, choices);
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) {
          var value =
              guessed ?? (choices.contains('DVD') ? 'DVD' : choices.first);
          return StatefulBuilder(
            builder: (ctx, setDlg) => AlertDialog(
              title: const Text('Converti tipologia media'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Nel file il formato "$raw" compare ${items.where((i) => i.format.trim().toLowerCase() == key).length} volte.'),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: value,
                      isExpanded: true,
                      items: choices
                          .map(
                              (f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlg(() => value = v);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Formato nell’app'),
                    ),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annulla import')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, value),
                    child: const Text('Applica a tutti')),
              ],
            ),
          );
        },
      );
      if (selected == null) return null;
      groups[key] = selected;
    }
    return {for (final e in groups.entries) e.key: e.value};
  }

  String? _guessFormat(String raw, List<String> choices) {
    final normalized = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    const aliases = <String, String>{
      'dvd': 'DVD',
      'digitalversatiledisc': 'DVD',
      'bluray': 'Blu-ray',
      'bd': 'Blu-ray',
      'uhd': 'Blu-ray 4K',
      '4kbluray': 'Blu-ray 4K',
      'bluray4k': 'Blu-ray 4K',
      'hddvd': 'HD-DVD',
      'vhs': 'VHS',
      'v2000': 'Video 2000',
      'video2000': 'Video 2000',
      'betamax': 'Betamax',
      'beta': 'Betamax',
      'laserdisc': 'LaserDisc',
      'ld': 'LaserDisc',
      'vcd': 'Video CD',
      'videocd': 'Video CD',
      'cdvideo': 'CD Video',
      'video8': 'Video8',
      'hi8': 'Hi8',
      'super8': 'Super 8',
      '8mm': '8mm',
      '16mm': '16mm',
      '35mm': '35mm',
    };
    final alias = aliases[normalized];
    if (alias != null && choices.contains(alias)) return alias;
    for (final format in choices) {
      if (format.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
          normalized) return format;
    }
    return null;
  }

  Future<void> _exportUnmatched() async {
    final ok = await IoService.saveText(
        'film_non_trovati_tmdb', 'csv', IoService.toCsv(_unmatched));
    if (ok) _snack('Elenco dei non trovati salvato');
  }

  Future<void> _searchUnmatched(MediaItem source, int index) async {
    final tmdb = context.read<AppState>().tmdb;
    if (tmdb == null) {
      _snack('Configura prima la chiave TMDB');
      return;
    }
    final ctrl = TextEditingController(text: source.title);
    List<TmdbResult> results = [];
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDlg) => AlertDialog(
                  title: Text('Cerca “${source.title}” su TMDB'),
                  content: SizedBox(
                      width: 520,
                      height: 400,
                      child: Column(children: [
                        TextField(
                            controller: ctrl,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) async {
                              results = await _searchAcrossLanguages(
                                  tmdb, ctrl.text, tmdb.lang);
                              setDlg(() {});
                            },
                            decoration: InputDecoration(
                                suffixIcon: IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: () async {
                                      results = await _searchAcrossLanguages(
                                          tmdb, ctrl.text, tmdb.lang);
                                      setDlg(() {});
                                    }))),
                        Expanded(
                            child: ListView(children: [
                          for (final r in results)
                            ListTile(
                                title: Text(r.title),
                                subtitle: Text('${r.year ?? ''} · ${r.type}'),
                                onTap: () async {
                                  final fresh =
                                      await tmdb.details(r.id, r.type);
                                  fresh
                                    ..format = source.format
                                    ..region = source.region
                                    ..mediaLanguage = source.mediaLanguage
                                    ..price = source.price
                                    ..barcode = source.barcode
                                    ..archived = source.archived
                                    ..lostMedia = source.lostMedia
                                    ..watched = source.watched
                                    ..notes = source.notes
                                    ..myRating = source.myRating
                                    ..qualityRating = source.qualityRating
                                    ..myReview = source.myReview
                                    ..loan = source.loan;
                                  context.read<AppState>().upsert(fresh);
                                  setState(() => _unmatched.removeAt(index));
                                  if (ctx.mounted) Navigator.pop(ctx);
                                })
                        ]))
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Chiudi'))
                  ],
                )));
    ctrl.dispose();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Svuotare tutto l\'archivio?'),
        content: const Text(
            'Verranno eliminati tutti i titoli. Esporta prima un backup se non sei sicuro.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Svuota')),
        ],
      ),
    );
    if (ok == true) context.read<AppState>().clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text('Impostazioni',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('TMDB'),
              Text(
                'Crea un account gratuito su themoviedb.org → Impostazioni → API, '
                'poi incolla qui la "API Key" oppure il "Read Access Token".',
                style: TextStyle(
                    color: adaptiveTextColor(context, opacity: .7),
                    fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Chiave TMDB'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue:
                    _langs.containsKey(s.tmdbLang) ? s.tmdbLang : 'en-US',
                decoration:
                    const InputDecoration(labelText: 'Lingua dei dati TMDB'),
                items: [
                  for (final e in _langs.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => s.updateSettings(lang: v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mediaLang,
                onChanged: (v) => s.updateSettings(mediaLang: v),
                decoration: const InputDecoration(
                  labelText: 'Lingua predefinita dei media',
                  helperText: 'Precompilata nei nuovi titoli',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _testing ? null : _saveKey,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified_outlined),
                label: const Text('Salva e verifica chiave'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: SwitchListTile(
            secondary: Icon(s.darkTheme ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Tema scuro'),
            subtitle: Text(s.darkTheme
                ? 'Tema scuro attivo (predefinito)'
                : 'Tema chiaro attivo'),
            value: s.darkTheme,
            onChanged: (value) => s.updateSettings(darkTheme: value),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: SwitchListTile(
            secondary: const Icon(Icons.speed_outlined),
            title: const Text('Riduci risorse'),
            subtitle: const Text(
                'Disattiva le macchie animate e mantiene solo lo sfondo a gradiente.'),
            value: s.reduceResources,
            onChanged: (value) => s.updateSettings(reduceResources: value),
          ),
        ),
        if (_matching) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Ricerca corrispondenze su TMDB…')),
        ],
        if (_unmatched.isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SectionTitle('Non trovati su TMDB (${_unmatched.length})',
                    trailing: IconButton(
                        onPressed: _exportUnmatched,
                        tooltip: 'Scarica CSV',
                        icon: const Icon(Icons.download))),
                Text(
                    'Cerca manualmente ciascun titolo e seleziona il risultato corretto.',
                    style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .7),
                        fontSize: 13)),
                const SizedBox(height: 8),
                for (var i = 0; i < _unmatched.length; i++)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_unmatched[i].title),
                      subtitle: Text(
                          '${_unmatched[i].year ?? 'Anno sconosciuto'} · ${_unmatched[i].format}'),
                      trailing: IconButton(
                          tooltip: 'Cerca su TMDB',
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchUnmatched(_unmatched[i], i))),
              ])),
        ],
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Aggiornamenti'),
              Text(
                'Controlla le release pubblicate su GitHub e installa la versione più recente disponibile per questo dispositivo.',
                style: TextStyle(
                    color: adaptiveTextColor(context, opacity: .7),
                    fontSize: 13),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _checkingUpdates ? null : _checkUpdates,
                icon: _checkingUpdates
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.system_update_alt),
                label: const Text('Controlla aggiornamenti'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Backup e importazione'),
              Text(
                'Il backup JSON contiene tutto (titoli, recensioni, prestiti, formati). '
                'L\'import accetta backup JSON, CSV e XML (anche da Filmotech).',
                style: TextStyle(
                    color: adaptiveTextColor(context, opacity: .7),
                    fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: s.items.isEmpty ? null : _exportJson,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Backup JSON'),
                ),
                FilledButton.tonalIcon(
                  onPressed: s.items.isEmpty ? null : _exportCsv,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Esporta CSV'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importa file'),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Formati dei media'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in s.formats)
                  InputChip(
                    avatar: FormatIcon(format: f, size: 22),
                    label: Text(f),
                    onDeleted: () => s.removeFormat(f),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _newFormat,
                    onSubmitted: (_) => _addFormat(s),
                    decoration: const InputDecoration(
                      labelText: 'Nuovo formato',
                      hintText: 'es. CED, Video CD, UMD…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                    onPressed: () => _addFormat(s),
                    icon: const Icon(Icons.add)),
              ]),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  for (final f in defaultFormats) {
                    s.addFormat(f);
                  }
                },
                child: const Text('Ripristina formati predefiniti'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Zona pericolosa'),
              OutlinedButton.icon(
                onPressed: s.items.isEmpty ? null : _clearAll,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Svuota archivio'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Media Archive 1.12\nQuesto prodotto usa l\'API di TMDB ma non è approvato o certificato da TMDB.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: adaptiveTextColor(context, opacity: .38), fontSize: 11),
          ),
        ),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Made With Love By',
                  style: TextStyle(
                      color: adaptiveTextColor(context, opacity: .54),
                      fontSize: 12)),
              TextButton(
                onPressed: _openCreatorLink,
                child: const Text('Luke133'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addFormat(AppState s) {
    final f = _newFormat.text.trim();
    if (f.isEmpty) return;
    s.addFormat(f);
    _newFormat.clear();
  }
}
