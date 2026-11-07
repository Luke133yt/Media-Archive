import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization.dart' show Text;
import '../models.dart';
import '../store.dart';
import 'detail_page.dart';
import 'glass.dart';
import 'person_page.dart';
import 'streaming_section.dart';

/// Scheda informativa TMDB per un film/serie dalla filmografia di un attore.
/// Non è la scheda della copia in collezione.
class TmdbInfoPage extends StatefulWidget {
  final int tmdbId;
  final String type;
  final String? fallbackTitle;

  const TmdbInfoPage({
    super.key,
    required this.tmdbId,
    required this.type,
    this.fallbackTitle,
  });

  @override
  State<TmdbInfoPage> createState() => _TmdbInfoPageState();
}

class _TmdbInfoPageState extends State<TmdbInfoPage> {
  late Future<MediaItem> _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<MediaItem> _load() async {
    final tmdb = context.read<AppState>().tmdb;
    if (tmdb == null) {
      throw StateError('Per aprire la scheda informativa serve TMDB.');
    }
    return tmdb.details(widget.tmdbId, widget.type);
  }

  MediaItem? _ownedCopy(AppState state, MediaItem info) {
    for (final item in state.items) {
      if (item.tmdbId != null &&
          item.tmdbId == info.tmdbId &&
          item.type == info.type) {
        return item;
      }
    }
    return null;
  }

  Future<void> _addToCollection(MediaItem info) async {
    final state = context.read<AppState>();
    final owned = _ownedCopy(state, info);
    if (owned != null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailPage(itemId: owned.id)),
      );
      return;
    }
    final copy = info.clone()
      ..format = 'Non Specificato'
      ..mediaLanguage = state.mediaLanguage;
    state.upsert(copy);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aggiunto alla collezione')),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailPage(itemId: copy.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final money = NumberFormat.simpleCurrency(name: 'USD');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fallbackTitle ?? 'Scheda film',
            localize: widget.fallbackTitle == null),
      ),
      body: FutureBuilder<MediaItem>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.movie_filter_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(snapshot.error.toString(),
                      localize: false, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => setState(() => _details = _load()),
                    child: const Text('Riprova'),
                  ),
                ]),
              ),
            );
          }
          final m = snapshot.data!;
          final owned = _ownedCopy(state, m);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Poster(
                      path: m.posterPath ?? m.backdropPath,
                      width: 130,
                      height: 195,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.title,
                              localize: false,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          if (m.originalTitle.isNotEmpty &&
                              m.originalTitle != m.title)
                            Text(m.originalTitle,
                                localize: false,
                                style: TextStyle(
                                    color: adaptiveTextColor(context,
                                        opacity: .6))),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (m.year != null) '${m.year}',
                              m.isTv ? 'Serie TV' : 'Film',
                              if (m.runtime != null) '${m.runtime} min',
                              if (m.seasons != null) '${m.seasons} stagioni',
                            ].join(' • '),
                            style: TextStyle(
                                color:
                                    adaptiveTextColor(context, opacity: .7)),
                          ),
                          if (m.voteAverage != null && m.voteAverage! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                    '${m.voteAverage!.toStringAsFixed(1)} TMDB'),
                              ]),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => _addToCollection(m),
                            icon: Icon(owned == null
                                ? Icons.library_add_outlined
                                : Icons.collections_bookmark_outlined),
                            label: Text(owned == null
                                ? 'Aggiungi alla collezione'
                                : 'Apri in collezione'),
                          ),
                          if (owned != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'In collezione come ${owned.format}',
                                style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .65),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StreamingSection(
                title: m.title,
                type: m.type,
                tmdbId: m.tmdbId,
                tmdb: state.tmdb,
              ),
              if (m.tagline.isNotEmpty || m.overview.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Trama'),
                      if (m.tagline.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('“${m.tagline}”',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: adaptiveTextColor(context,
                                      opacity: .7))),
                        ),
                      Text(m.overview, localize: false),
                      if (m.genres.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final g in m.genres)
                            Chip(
                                label: Text(g, localize: false),
                                visualDensity: VisualDensity.compact),
                        ]),
                      ],
                      if (m.director != null && m.director!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${m.isTv ? 'Creato da' : 'Regia'}: ${m.director}',
                          style: TextStyle(
                              color:
                                  adaptiveTextColor(context, opacity: .7)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (m.budget != null || m.revenue != null) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Botteghino'),
                      if (m.budget != null)
                        Text('Budget: ${money.format(m.budget)}'),
                      if (m.revenue != null)
                        Text(
                            'Incasso mondiale: ${money.format(m.revenue)}'),
                    ],
                  ),
                ),
              ],
              if (m.cast.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Cast'),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: m.cast.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final c = m.cast[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PersonPage(person: c)));
                              },
                              child: SizedBox(
                                width: 84,
                                child: Column(children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: c.profilePath == null
                                          ? Container(
                                              color: Colors.white10,
                                              child: const Icon(Icons.person))
                                          : Poster(
                                              path: c.profilePath,
                                              width: 72,
                                              height: 72,
                                              radius: 0,
                                              size: 'w185'),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(c.name,
                                      localize: false,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  Text(c.character,
                                      localize: false,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: adaptiveTextColor(context,
                                              opacity: .54))),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (m.reviews.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Recensioni (TMDB)'),
                      for (final r in m.reviews)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.author}${r.rating != null ? '  •  ★ ${r.rating!.toStringAsFixed(0)}/10' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(r.content,
                                  localize: false,
                                  style: TextStyle(
                                      color: adaptiveTextColor(context,
                                          opacity: .7))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Scheda informativa TMDB. Non corrisponde alla tua copia fisica.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: adaptiveTextColor(context, opacity: .38),
                      fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
