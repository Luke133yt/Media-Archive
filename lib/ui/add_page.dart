import 'package:flutter/material.dart' hide Text;
import '../localization.dart' show AppStrings, Text;
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../tmdb.dart';
import 'edit_page.dart';
import 'glass.dart';
import 'scanner.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _ctrl = TextEditingController();
  List<TmdbResult> _results = [];
  bool _loading = false;
  String? _error;
  String _barcode = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    final tmdb = context.read<AppState>().tmdb;
    if (tmdb == null) {
      setState(() => _error =
          'Inserisci prima la tua chiave TMDB in Impostazioni (è gratuita).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await tmdb.search(q);
      setState(() {
        _results = r;
        if (r.isEmpty) _error = 'Nessun risultato per "$q".';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || code.isEmpty) return;
    setState(() {
      _barcode = code;
      _loading = true;
      _error = null;
    });
    final title = await lookupBarcodeTitle(code);
    if (!mounted) return;
    if (title != null) {
      _ctrl.text = title;
      await _search();
    } else {
      setState(() {
        _loading = false;
        _error =
            'Codice $code acquisito, ma non ho trovato il titolo. Cercalo a mano: il codice resterà associato.';
      });
    }
  }

  Future<void> _pick(TmdbResult r) async {
    final state = context.read<AppState>();
    final tmdb = state.tmdb;
    if (tmdb == null) return;
    setState(() => _loading = true);
    try {
      final item = await tmdb.details(r.id, r.type);
      item.barcode = _barcode;
      item.mediaLanguage = state.mediaLanguage;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditPage(item: item, isNew: true),
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _manual() {
    final state = context.read<AppState>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditPage(
        item: MediaItem(
          barcode: _barcode,
          mediaLanguage: state.mediaLanguage,
        ),
        isNew: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aggiungi titolo')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                    hintText: AppStrings.translate(
                        'Cerca su TMDB (film o serie TV)'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _search,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip:
                      AppStrings.translate('Scansiona codice a barre'),
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ]),
            ),
            if (_barcode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    avatar: const Icon(Icons.qr_code, size: 18),
                    label: Text('Barcode $_barcode'),
                    onDeleted: () => setState(() => _barcode = ''),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _manual,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Inserisci a mano (senza TMDB)'),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassCard(
                  child: Text(_error!,
                      style: TextStyle(
                          color: adaptiveTextColor(context, opacity: .7))),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return GlassCard(
                    padding: const EdgeInsets.all(10),
                    radius: 20,
                    onTap: () => _pick(r),
                    child: Row(children: [
                      Poster(
                          path: r.posterPath,
                          width: 56,
                          height: 84,
                          radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title,
                                localize: false,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              [
                                if (r.year != null) '${r.year}',
                                r.type == 'tv' ? 'Serie TV' : 'Film',
                              ].join(' • '),
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .6)),
                            ),
                            const SizedBox(height: 4),
                            Text(r.overview,
                                localize: false,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color:
                                        adaptiveTextColor(context, opacity: .7),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
