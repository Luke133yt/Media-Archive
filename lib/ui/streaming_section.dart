import 'package:flutter/material.dart' hide Text;
import 'package:cached_network_image/cached_network_image.dart';

import '../localization.dart' show Text;
import '../models.dart';
import '../streaming.dart';
import '../tmdb.dart';
import 'glass.dart';

class StreamingSection extends StatefulWidget {
  final String title;
  final String type;
  final int? tmdbId;
  final TmdbClient? tmdb;
  final bool showWatchCta;

  const StreamingSection({
    super.key,
    required this.title,
    required this.type,
    required this.tmdbId,
    required this.tmdb,
    this.showWatchCta = true,
  });

  @override
  State<StreamingSection> createState() => _StreamingSectionState();
}

class _StreamingSectionState extends State<StreamingSection> {
  late Future<_StreamingData> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant StreamingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tmdbId != widget.tmdbId ||
        oldWidget.type != widget.type ||
        oldWidget.tmdb != widget.tmdb) {
      _future = _load();
    }
  }

  Future<_StreamingData> _load() async {
    final tmdb = widget.tmdb;
    final id = widget.tmdbId;
    if (tmdb == null || id == null) {
      return _StreamingData(
        targets: StreamingLinks.buildTargets(
          title: widget.title,
          type: widget.type,
          tmdbId: id,
        ),
      );
    }
    List<TmdbVideo> videos = const [];
    WatchProvidersResult? providers;
    String? imdb;
    try {
      videos = await tmdb.videos(id, widget.type);
    } catch (_) {}
    try {
      providers = await tmdb.watchProviders(id, widget.type);
    } catch (_) {}
    try {
      imdb = await tmdb.imdbId(id, widget.type);
    } catch (_) {}
    final trailer = StreamingLinks.youtubeTrailer(videos);
    return _StreamingData(
      trailer: trailer,
      trailerName: videos.isEmpty ? null : videos.first.name,
      targets: StreamingLinks.buildTargets(
        title: widget.title,
        type: widget.type,
        tmdbId: id,
        imdbId: imdb,
        providers: providers,
        trailerUri: trailer,
      ),
      availableCount: providers?.providers.length ?? 0,
    );
  }

  Future<void> _open(StreamingTarget target) async {
    final ok = await StreamingLinks.open(target.uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire ${target.label}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StreamingData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Guarda e trailer'),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else ...[
                if (data?.trailer != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline, size: 36),
                    title: const Text('Trailer'),
                    subtitle: Text(
                      data!.trailerName?.isNotEmpty == true
                          ? data.trailerName!
                          : 'Apri il trailer su YouTube',
                      localize: data.trailerName?.isNotEmpty != true,
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => StreamingLinks.open(data.trailer!),
                  ),
                  const SizedBox(height: 4),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nessun trailer trovato su TMDB.',
                      style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .6),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (widget.showWatchCta) ...[
                  FilledButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                        _expanded ? Icons.expand_less : Icons.play_arrow_rounded),
                    label: Text(_expanded
                        ? 'Nascondi piattaforme'
                        : 'Guarda in streaming'),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    Text(
                      data != null && data.availableCount > 0
                          ? 'Disponibile su ${data.availableCount} piattaforme (JustWatch/TMDB). Nuvio e Stremio restano sempre disponibili.'
                          : 'Nuvio e Stremio sono sempre disponibili. Le altre piattaforme aprono la ricerca del titolo.',
                      style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .65),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in data?.targets ?? const <StreamingTarget>[])
                          _StreamingChip(
                            target: t,
                            onTap: () => _open(t),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StreamingData {
  final Uri? trailer;
  final String? trailerName;
  final List<StreamingTarget> targets;
  final int availableCount;

  const _StreamingData({
    this.trailer,
    this.trailerName,
    required this.targets,
    this.availableCount = 0,
  });
}

class _StreamingChip extends StatelessWidget {
  final StreamingTarget target;
  final VoidCallback onTap;

  const _StreamingChip({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final logo = target.logoUrl;
    return ActionChip(
      avatar: logo == null
          ? Icon(
              target.id == 'nuvio' || target.id == 'stremio'
                  ? Icons.live_tv_outlined
                  : Icons.open_in_new,
              size: 18,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: logo,
                width: 18,
                height: 18,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 18),
              ),
            ),
      label: Text(target.label, localize: false),
      onPressed: onTap,
    );
  }
}
