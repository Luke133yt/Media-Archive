import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../formats.dart';
import '../models.dart';
import '../store.dart';
import 'format_icon.dart';
import 'glass.dart';
import 'image_gallery.dart';
import 'scanner.dart';

/// Form usato sia per aggiungere (dopo TMDB o a mano) sia per modificare.
class EditPage extends StatefulWidget {
  final MediaItem item;
  final bool isNew;
  const EditPage({super.key, required this.item, this.isNew = false});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late final MediaItem _m = widget.item.clone();
  late final _title = TextEditingController(text: _m.title);
  late final _original = TextEditingController(text: _m.originalTitle);
  late final _year = TextEditingController(text: _m.year?.toString() ?? '');
  late final _overview = TextEditingController(text: _m.overview);
  late final _region = TextEditingController(text: _m.region);
  late final _lang = TextEditingController(text: _m.mediaLanguage);
  late final _price = TextEditingController(
      text: _m.price == null ? '' : _m.price!.toStringAsFixed(2));
  late final _barcode = TextEditingController(text: _m.barcode);
  late final _notes = TextEditingController(text: _m.notes);
  final _newFormat = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    for (final c in [
      _title,
      _original,
      _year,
      _overview,
      _region,
      _lang,
      _price,
      _barcode,
      _notes,
      _newFormat,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addFormat() {
    final f = _newFormat.text.trim();
    if (f.isEmpty) return;
    final state = context.read<AppState>();
    state.addFormat(f);
    // usa il nome già esistente se differisce solo per maiuscole
    final existing = state.formats
        .firstWhere((e) => e.toLowerCase() == f.toLowerCase(), orElse: () => f);
    setState(() {
      _m.format = existing;
      _newFormat.clear();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _m
      ..title = _title.text.trim()
      ..originalTitle = _original.text.trim()
      ..year = int.tryParse(_year.text.trim())
      ..overview = _overview.text.trim()
      ..region = _region.text.trim()
      ..mediaLanguage = _lang.text.trim()
      ..price = double.tryParse(_price.text.trim().replaceAll(',', '.'))
      ..barcode = _barcode.text.trim()
      ..notes = _notes.text.trim();
    context.read<AppState>().upsert(_m);
    if (widget.isNew) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Nuovo titolo' : 'Modifica'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Salva'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              if (_m.tmdbId != null ||
                  _m.posterPath != null ||
                  _m.localPosterPath != null ||
                  _m.backdropPath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => openMediaGallery(
                        context,
                        title: _m.title,
                        type: _m.type,
                        tmdbId: _m.tmdbId,
                        localPosterPath: _m.localPosterPath,
                        posterPath: _m.posterPath,
                        backdropPath: _m.backdropPath,
                        tmdb: context.read<AppState>().tmdb,
                      ),
                      child: Poster(
                          path: _m.localPosterPath ??
                              _m.posterPath ??
                              _m.backdropPath,
                          fallbackPath: _m.localPosterPath != null
                              ? _m.posterPath ?? _m.backdropPath
                              : (_m.posterPath != null
                                  ? _m.backdropPath
                                  : null),
                          width: 130,
                          height: 195),
                    ),
                  ),
                ),
              GlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Locandina'),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                      type: FileType.image, withData: true);
                              final selected = result?.files.single;
                              if (selected == null) return;
                              final bytes = selected.bytes;
                              final sourcePath = selected.path;
                              if (bytes == null && sourcePath == null) return;
                              final dir =
                                  await getApplicationSupportDirectory();
                              final ext = selected.extension ?? 'jpg';
                              final dest =
                                  '${dir.path}${Platform.pathSeparator}poster_${_m.id}_${DateTime.now().microsecondsSinceEpoch}.$ext';
                              if (bytes != null) {
                                await File(dest).writeAsBytes(bytes);
                              } else {
                                await File(sourcePath!).copy(dest);
                              }
                              if (mounted)
                                setState(() {
                                  _m.localPosterPath = dest;
                                });
                            },
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Scegli immagine')),
                        if (_m.localPosterPath != null)
                          TextButton.icon(
                              onPressed: () =>
                                  setState(() => _m.localPosterPath = null),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Rimuovi')),
                      ]),
                      Text(
                          'L’immagine viene letta dal percorso selezionato sul dispositivo.',
                          style: TextStyle(
                              color: adaptiveTextColor(context, opacity: .6),
                              fontSize: 12)),
                    ]),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'movie',
                          icon: Icon(Icons.movie_outlined),
                          label: Text('Film')),
                      ButtonSegment(
                          value: 'tv',
                          icon: Icon(Icons.tv),
                          label: Text('Serie TV')),
                    ],
                    selected: {_m.type},
                    onSelectionChanged: (v) =>
                        setState(() => _m.type = v.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Inserisci un titolo'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _original,
                    decoration:
                        const InputDecoration(labelText: 'Titolo originale'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Anno'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _overview,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Trama'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Supporto'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in state.formats)
                          ChoiceChip(
                            avatar: FormatIcon(
                              format: f,
                              size: 24,
                              posterPath: _m.format == f ? _m.posterPath : null,
                            ),
                            label: Text(f),
                            selected: _m.format == f,
                            onSelected: (_) => setState(() => _m.format = f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _newFormat,
                          onSubmitted: (_) => _addFormat(),
                          decoration: const InputDecoration(
                            labelText: 'Altro formato',
                            hintText: 'Scrivi un formato e premi +',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _addFormat,
                        icon: const Icon(Icons.add),
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
                    const SectionTitle('Dettagli della tua copia'),
                    TextFormField(
                      controller: _region,
                      decoration: const InputDecoration(
                        labelText: 'Standard / regione',
                        hintText: 'PAL, NTSC, Region 2…',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final r in regionPresets)
                          ActionChip(
                            label:
                                Text(r, style: const TextStyle(fontSize: 12)),
                            onPressed: () => setState(() => _region.text = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lang,
                      decoration:
                          const InputDecoration(labelText: 'Lingua del media'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Prezzo pagato', prefixText: '€ '),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _barcode,
                      decoration: InputDecoration(
                        labelText: 'Codice a barre',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () async {
                            final c = await scanBarcode(context);
                            if (c != null) setState(() => _barcode.text = c);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Archiviato sul server'),
                      subtitle: const Text(
                          'Hai già copiato questo media sul tuo archivio locale'),
                      value: _m.archived,
                      onChanged: (v) => setState(() => _m.archived = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.search_off_outlined),
                      title: const Text('Lost Media'),
                      subtitle: const Text(
                          'Questo media è considerato perduto o irreperibile'),
                      value: _m.lostMedia,
                      onChanged: (v) => setState(() => _m.lostMedia = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.visibility_outlined),
                      title: const Text('Già visto'),
                      value: _m.watched,
                      onChanged: (v) => setState(() => _m.watched = v),
                    ),
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Note'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
