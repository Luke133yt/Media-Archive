import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;

import '../formats.dart';
import '../tmdb.dart';

/// Icona "render" del supporto (disco, cassetta, bobina) disegnata in codice.
/// Per i dischi, se passi [posterPath], la copertina diventa l'etichetta.
class FormatIcon extends StatelessWidget {
  final String format;
  final double size;
  final String? posterPath;
  const FormatIcon({
    super.key,
    required this.format,
    this.size = 40,
    this.posterPath,
  });

  @override
  Widget build(BuildContext context) {
    final st = styleFor(format);
    final painter = switch (st.kind) {
      FormatKind.disc => _DiscPainter(Color(st.base), Color(st.accent)),
      FormatKind.cassette => _CassettePainter(Color(st.base), Color(st.accent)),
      FormatKind.reel => _ReelPainter(Color(st.base), Color(st.accent)),
      FormatKind.generic => _GenericPainter(Color(st.base), Color(st.accent)),
    };
    final url = TmdbClient.img(posterPath, size: 'w154');
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: painter),
          if (st.kind == FormatKind.disc && url.isNotEmpty)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: size * 0.42,
                height: size * 0.42,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cinque supporti DVD selezionabili a mezzi voti.
class DiscRating extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  final double size;

  const DiscRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 5; index++)
            SizedBox(
              width: size,
              height: size,
              child: Stack(children: [
                Opacity(
                  opacity: 0.24,
                  child: FormatIcon(format: 'DVD', size: size),
                ),
                ClipRect(
                  clipper:
                      _DiscFillClipper(((value ?? 0) - index).clamp(0.0, 1.0)),
                  child: FormatIcon(format: 'DVD', size: size),
                ),
                Positioned.fill(
                  child: Row(children: [
                    for (final half in [0.5, 1.0])
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Qualità ${index + half} su 5 DVD',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final selected = index + half;
                              onChanged(value == selected ? null : selected);
                            },
                          ),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
        ],
      );
}

class _DiscFillClipper extends CustomClipper<Rect> {
  final double fraction;
  const _DiscFillClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _DiscFillClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _DiscPainter extends CustomPainter {
  final Color base;
  final Color accent;
  _DiscPainter(this.base, this.accent);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 * 0.95;
    final rect = Rect.fromCircle(center: c, radius: r);

    // ombra
    canvas.drawCircle(
      c.translate(0, r * 0.06),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    // corpo con riflesso conico
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(colors: [
          base,
          Color.lerp(base, Colors.white, 0.65)!,
          base,
          Color.lerp(base, Colors.black, 0.25)!,
          Color.lerp(base, Colors.white, 0.55)!,
          base,
        ]).createShader(rect),
    );
    // anello colorato (identifica Blu-ray / HD-DVD ecc.)
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = accent.withValues(alpha: 0.85),
    );
    // mozzo
    canvas.drawCircle(
        c, r * 0.30, Paint()..color = Colors.white.withValues(alpha: 0.22));
    canvas.drawCircle(
        c,
        r * 0.30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawCircle(c, r * 0.09, Paint()..color = const Color(0xFF0B0E22));
    // bordo esterno lucido
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant _DiscPainter o) =>
      o.base != base || o.accent != accent;
}

class _CassettePainter extends CustomPainter {
  final Color base;
  final Color label;
  _CassettePainter(this.base, this.label);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width * 0.96;
    final h = s.width * 0.62;
    final rect =
        Rect.fromCenter(center: s.center(Offset.zero), width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.12));

    canvas.drawRRect(
      rr.shift(Offset(0, h * 0.06)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.1),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.25)!, base],
        ).createShader(rect),
    );
    // etichetta
    final lab = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          rect.left + w * 0.08, rect.top + h * 0.1, w * 0.84, h * 0.34),
      Radius.circular(h * 0.05),
    );
    canvas.drawRRect(lab, Paint()..color = label.withValues(alpha: 0.92));
    // finestra bobine
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          rect.left + w * 0.22, rect.top + h * 0.52, w * 0.56, h * 0.28),
      Radius.circular(h * 0.14),
    );
    canvas.drawRRect(win, Paint()..color = const Color(0xFF0B0E22));
    for (final dx in [0.36, 0.64]) {
      final p = Offset(rect.left + w * dx, rect.top + h * 0.66);
      canvas.drawCircle(p, h * 0.095, Paint()..color = Colors.white70);
      canvas.drawCircle(p, h * 0.035, Paint()..color = const Color(0xFF0B0E22));
    }
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(covariant _CassettePainter o) =>
      o.base != base || o.label != label;
}

class _ReelPainter extends CustomPainter {
  final Color base;
  final Color accent;
  _ReelPainter(this.base, this.accent);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 * 0.95;
    canvas.drawCircle(
      c.translate(0, r * 0.06),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(base, Colors.white, 0.3)!, base],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // pellicola avvolta
    canvas.drawCircle(
        c,
        r * 0.82,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..color = accent.withValues(alpha: 0.9));
    // fori
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.45,
        r * 0.13,
        Paint()..color = const Color(0xFF0B0E22),
      );
    }
    canvas.drawCircle(c, r * 0.1, Paint()..color = Colors.white70);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _ReelPainter o) =>
      o.base != base || o.accent != accent;
}

class _GenericPainter extends CustomPainter {
  final Color base;
  final Color accent;
  _GenericPainter(this.base, this.accent);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Rect.fromCenter(
        center: s.center(Offset.zero),
        width: s.width * 0.8,
        height: s.width * 0.8);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s.width * 0.16));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(base, Colors.white, 0.3)!, base],
        ).createShader(rect),
    );
    final path = Path()
      ..moveTo(rect.center.dx - rect.width * 0.14,
          rect.center.dy - rect.height * 0.2)
      ..lineTo(rect.center.dx + rect.width * 0.22, rect.center.dy)
      ..lineTo(rect.center.dx - rect.width * 0.14,
          rect.center.dy + rect.height * 0.2)
      ..close();
    canvas.drawPath(path, Paint()..color = accent);
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(covariant _GenericPainter o) =>
      o.base != base || o.accent != accent;
}
