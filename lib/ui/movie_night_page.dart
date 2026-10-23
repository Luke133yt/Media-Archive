import 'package:flutter/material.dart';

import '../io_service.dart';
import '../models.dart';
import 'format_icon.dart';
import 'glass.dart';

/// Collezione temporanea: non passa mai da AppState e non viene salvata.
class MovieNightPage extends StatefulWidget {
  const MovieNightPage({super.key});

  @override
  State<MovieNightPage> createState() => _MovieNightPageState();
}

class _MovieNightPageState extends State<MovieNightPage> {
  List<MediaItem> _items = [];
  String _query = '';
  String? _type;
  bool _loading = false;
  String? _error;
  String? _fileName;

  Future<void> _importCsv() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picked = await IoService.pickCsv();
      if (!mounted) return;
      if (picked == null) return;
      final parsed = IoService.parseAny(picked.$1, picked.$2);
      setState(() {
        _items = parsed.items;
        _fileName = picked.$1;
        _query = '';
        _type = null;
        if (_items.isEmpty) {
          _error = 'Non ho trovato titoli nel CSV selezionato.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossibile leggere il CSV: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MediaItem> get _visibleItems {
    final q = _query.trim().toLowerCase();
    final result = _items.where((item) {
      if (_type != null && item.type != _type) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.originalTitle.toLowerCase().contains(q) ||
          item.format.toLowerCase().contains(q) ||
          (item.director ?? '').toLowerCase().contains(q) ||
          item.cast.any((person) => person.name.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return result;
  }

  void _showDetails(MediaItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.posterPath != null || item.localPosterPath != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Poster(
                        path: item.localPosterPath ?? item.posterPath,
                        width: 150,
                        height: 225,
                      ),
                    ),
                  ),
                Text(
                    [
                      if (item.year != null) item.year.toString(),
                      item.type == 'tv' ? 'Serie TV' : 'Film',
                      if (item.format.isNotEmpty) item.format,
                    ].join(' · '),
                    style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .7))),
                if (item.director?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text('Regia: ${item.director}'),
                ],
                if (item.overview.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item.overview),
                ],
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Note: ${item.notes}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Night'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Rimuovi collezione temporanea',
              onPressed: () => setState(() {
                _items = [];
                _fileName = null;
                _query = '';
                _type = null;
              }),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.movie_filter_outlined,
                            size: 64,
                            color: adaptiveTextColor(context, opacity: .7)),
                        const SizedBox(height: 16),
                        Text('Movie Night!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          'Importa la collezione di un amico e scegli il film da vedere stasera. Il CSV sarà consultabile solo per questa sessione e non verrà aggiunto al tuo archivio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: adaptiveTextColor(context, opacity: .7),
                              height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _loading ? null : _importCsv,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.file_upload_outlined),
                          label: const Text('Importa collezione CSV'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.orange)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fileName ?? 'Collezione condivisa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          Text('${visible.length} di ${_items.length} titoli',
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .7))),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loading ? null : _importCsv,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Cambia CSV'),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cerca titolo, regista, attore, formato…',
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      FilterChip(
                        label: const Text('Film'),
                        selected: _type == 'movie',
                        onSelected: (selected) =>
                            setState(() => _type = selected ? 'movie' : null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Serie TV'),
                        selected: _type == 'tv',
                        onSelected: (selected) =>
                            setState(() => _type = selected ? 'tv' : null),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text('Nessun titolo corrisponde alla ricerca.',
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .7))))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.54,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return GlassCard(
                              padding: EdgeInsets.zero,
                              radius: 22,
                              onTap: () => _showDetails(item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Poster(
                                            path: item.localPosterPath ??
                                                item.posterPath ??
                                                item.backdropPath,
                                            radius: 0),
                                        Positioned(
                                          left: 8,
                                          bottom: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                FormatIcon(
                                                    format: item.format,
                                                    size: 18),
                                                const SizedBox(width: 4),
                                                Text(item.format,
                                                    style: const TextStyle(
                                                        fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            '${item.year ?? 'Anno sconosciuto'} · ${item.type == 'tv' ? 'Serie TV' : 'Film'}',
                                            style: TextStyle(
                                                color: adaptiveTextColor(
                                                    context,
                                                    opacity: .6),
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
