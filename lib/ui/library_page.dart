import 'package:flutter/material.dart' hide Text;
import '../localization.dart' show AppStrings, Text;
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import 'detail_page.dart';
import 'format_icon.dart';
import 'glass.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _q = '';
  String? _type;
  String? _format;
  bool _loanedOnly = false;
  bool _notArchived = false;
  bool _lostMediaOnly = false;
  String _sort = 'title';

  List<MediaItem> _filtered(AppState s) {
    final q = _q.trim().toLowerCase();
    final list = s.items.where((i) {
      if (_type != null && i.type != _type) return false;
      if (_format != null && i.format != _format) return false;
      if (_loanedOnly && i.loan == null) return false;
      if (_notArchived && i.archived) return false;
      if (_lostMediaOnly && !i.lostMedia) return false;
      if (q.isEmpty) return true;
      return i.title.toLowerCase().contains(q) ||
          i.originalTitle.toLowerCase().contains(q) ||
          i.format.toLowerCase().contains(q) ||
          i.barcode.contains(q) ||
          (i.director ?? '').toLowerCase().contains(q) ||
          i.cast.any((c) => c.name.toLowerCase().contains(q));
    }).toList();

    int cmp(MediaItem a, MediaItem b) {
      switch (_sort) {
        case 'year':
          return (b.year ?? 0).compareTo(a.year ?? 0);
        case 'added':
          return b.addedAt.compareTo(a.addedAt);
        case 'rating':
          return (b.myRating ?? -1).compareTo(a.myRating ?? -1);
        default:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    }

    list.sort(cmp);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = _filtered(s);
    final usedFormats = s.items.map((e) => e.format).toSet().toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/branding/media_archive_logo.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Media Archive',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  Text(
                    '${s.items.length} titoli in collezione'
                    '${list.length != s.items.length ? ' • ${list.length} mostrati' : ''}',
                    style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .7)),
                  ),
                ],
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            radius: 22,
            child: Row(children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.search,
                    color: adaptiveTextColor(context, opacity: .7)),
              ),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: AppStrings.translate(
                        'Cerca titolo, regista, attore, barcode…'),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppStrings.translate('Ordina'),
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'title', child: Text('Titolo')),
                  PopupMenuItem(value: 'year', child: Text('Anno')),
                  PopupMenuItem(
                      value: 'added', child: Text('Aggiunti di recente')),
                  PopupMenuItem(value: 'rating', child: Text('Mio voto')),
                ],
              ),
            ]),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _chip('Film', _type == 'movie',
                  (v) => setState(() => _type = v ? 'movie' : null)),
              _chip('Serie TV', _type == 'tv',
                  (v) => setState(() => _type = v ? 'tv' : null)),
              _chip('In prestito', _loanedOnly,
                  (v) => setState(() => _loanedOnly = v)),
              _chip('Non archiviati', _notArchived,
                  (v) => setState(() => _notArchived = v)),
              _chip('Lost Media', _lostMediaOnly,
                  (v) => setState(() => _lostMediaOnly = v)),
              for (final f in usedFormats)
                _chip(f, _format == f,
                    (v) => setState(() => _format = v ? f : null)),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.album_outlined,
                            size: 72,
                            color: adaptiveTextColor(context, opacity: .38)),
                        const SizedBox(height: 12),
                        Text(
                          s.items.isEmpty
                              ? 'La tua collezione è vuota.\nPremi + per aggiungere il primo titolo.'
                              : 'Nessun risultato con questi filtri.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: adaptiveTextColor(context, opacity: .7)),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.54,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _Tile(item: list[i]),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onSel) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: onSel,
        ),
      );
}

class _Tile extends StatelessWidget {
  final MediaItem item;
  const _Tile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 22,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailPage(itemId: item.id)),
      ),
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
                    fallbackPath: item.localPosterPath != null
                        ? item.posterPath ?? item.backdropPath
                        : (item.posterPath != null ? item.backdropPath : null),
                    radius: 0),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      FormatIcon(format: item.format, size: 22),
                      const SizedBox(width: 5),
                      Text(item.format,
                          localize: false,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                if (item.loan != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.swap_horiz,
                          size: 16, color: Colors.black),
                    ),
                  ),
                if (item.archived)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.dns, size: 14, color: Colors.white),
                    ),
                  ),
                if (item.lostMedia)
                  Positioned(
                    top: 8,
                    right: item.archived ? 42 : 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_off,
                          size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    localize: false,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (item.year != null) '${item.year}',
                    if (item.isTv) 'Serie TV',
                  ].join(' • '),
                  style: TextStyle(
                      color: adaptiveTextColor(context, opacity: .6),
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
