import 'dart:io';

import 'package:flutter/material.dart';

import '../tmdb.dart';
import 'glass.dart';

class GalleryPhoto {
  final String path;
  const GalleryPhoto(this.path);

  bool get isLocal =>
      path.startsWith('file://') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
}

Future<void> openMediaGallery(
  BuildContext context, {
  required String title,
  required String type,
  required int? tmdbId,
  required String? localPosterPath,
  required String? posterPath,
  required String? backdropPath,
  required TmdbClient? tmdb,
}) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => _ImageGalleryPage(
      title: title,
      type: type,
      tmdbId: tmdbId,
      localPosterPath: localPosterPath,
      posterPath: posterPath,
      backdropPath: backdropPath,
      tmdb: tmdb,
    ),
  ));
}

class _ImageGalleryPage extends StatefulWidget {
  final String title;
  final String type;
  final int? tmdbId;
  final String? localPosterPath;
  final String? posterPath;
  final String? backdropPath;
  final TmdbClient? tmdb;

  const _ImageGalleryPage({
    required this.title,
    required this.type,
    required this.tmdbId,
    required this.localPosterPath,
    required this.posterPath,
    required this.backdropPath,
    required this.tmdb,
  });

  @override
  State<_ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<_ImageGalleryPage> {
  final _controller = PageController();
  late final Future<List<GalleryPhoto>> _photos = _loadPhotos();
  int _index = 0;

  Future<List<GalleryPhoto>> _loadPhotos() async {
    final photos = <GalleryPhoto>[];
    void add(String? path) {
      final value = path?.trim() ?? '';
      if (value.isNotEmpty && !photos.any((photo) => photo.path == value)) {
        photos.add(GalleryPhoto(value));
      }
    }

    // La copertina corrente (anche locale) è sempre la prima dell’album.
    add(widget.localPosterPath ?? widget.posterPath ?? widget.backdropPath);
    add(widget.posterPath);
    add(widget.backdropPath);
    if (widget.tmdb != null && widget.tmdbId != null) {
      try {
        for (final path
            in await widget.tmdb!.mediaImages(widget.tmdbId!, widget.type)) {
          add(path);
        }
      } catch (e) {
        debugPrint('Impossibile caricare la galleria TMDB: $e');
      }
    }
    return photos;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _photo(GalleryPhoto photo) {
    if (photo.isLocal) {
      final file = photo.path.startsWith('file://')
          ? File.fromUri(Uri.parse(photo.path))
          : File(photo.path);
      return Image.file(file,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _ImageUnavailable());
    }
    return Image.network(
      TmdbClient.img(photo.path, size: 'original'),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) => const _ImageUnavailable(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF05060B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF05060B),
          title: FutureBuilder<List<GalleryPhoto>>(
            future: _photos,
            builder: (_, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Text(count == 0
                  ? widget.title
                  : '${widget.title} · ${_index + 1}/$count');
            },
          ),
        ),
        body: FutureBuilder<List<GalleryPhoto>>(
          future: _photos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final photos = snapshot.data ?? const <GalleryPhoto>[];
            if (photos.isEmpty) return const _ImageUnavailable();
            return Stack(children: [
              PageView.builder(
                controller: _controller,
                itemCount: photos.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (_, index) => Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: _photo(photos[index]),
                  ),
                ),
              ),
              if (_index > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    tooltip: 'Foto precedente',
                    onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
              if (_index < photos.length - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filledTonal(
                    tooltip: 'Foto successiva',
                    onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48, color: adaptiveTextColor(context, opacity: .54)),
          const SizedBox(height: 12),
          Text('Nessuna immagine disponibile',
              style: TextStyle(color: adaptiveTextColor(context, opacity: .7))),
        ]),
      );
}
