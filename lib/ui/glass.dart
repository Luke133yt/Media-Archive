import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../tmdb.dart';

ThemeData buildTheme({bool darkTheme = true}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7C9CFF),
    brightness: darkTheme ? Brightness.dark : Brightness.light,
  );
  final foreground = darkTheme ? Colors.white : const Color(0xFF182033);
  final outline = darkTheme ? Colors.white : const Color(0xFF182033);
  OutlineInputBorder border(double a) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: outline.withValues(alpha: a)),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: foreground.withValues(alpha: darkTheme ? 0.07 : 0.045),
      border: border(0.16),
      enabledBorder: border(0.16),
      focusedBorder: border(0.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: foreground.withValues(alpha: darkTheme ? 0.07 : 0.045),
      selectedColor: scheme.primary.withValues(alpha: 0.35),
      side:
          BorderSide(color: outline.withValues(alpha: darkTheme ? 0.18 : 0.14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor:
          darkTheme ? const Color(0xF21A1F3D) : const Color(0xFFF8F9FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF2252B52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: foreground.withValues(alpha: darkTheme ? 0.16 : 0.10),
    ),
  );
}

Color adaptiveTextColor(BuildContext context, {double opacity = 1}) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);

/// Sfondo con "macchie" di colore animate, visibili attraverso il vetro.
class GlassBackground extends StatefulWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with TickerProviderStateMixin {
  AnimationController? _c;
  bool _reduceResources = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = context.watch<AppState>().reduceResources;
    if (reduce == _reduceResources) return;
    _reduceResources = reduce;
    if (reduce) {
      _c?.dispose();
      _c = null;
    } else {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 28),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _blob(Alignment a, double size, Color color) => Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().darkTheme;
    final background = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF080B1F), Color(0xFF1A1040), Color(0xFF0A1B2E)]
              : const [Color(0xFFF1F4FC), Color(0xFFE8EBF7), Color(0xFFEAF4F6)],
        ),
      ),
    );
    if (_reduceResources || _c == null) {
      return Stack(fit: StackFit.expand, children: [background, widget.child]);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        AnimatedBuilder(
          animation: _c!,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_c!.value);
            return Stack(children: [
              _blob(Alignment(-0.9 + 0.7 * t, -0.8 + 0.3 * t), 520,
                  const Color(0xFF4F6BFF)),
              _blob(Alignment(0.95 - 0.6 * t, -0.2 + 0.6 * t), 460,
                  const Color(0xFFB04CFF)),
              _blob(Alignment(-0.3 + 0.5 * t, 0.95 - 0.3 * t), 520,
                  const Color(0xFF00C2C7)),
            ]);
          },
        ),
        widget.child,
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = 26,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Colors.white : const Color(0xFF172033);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: dark ? 0.20 : 0.055),
                tint.withValues(alpha: dark ? 0.05 : 0.018),
              ],
            ),
            border: Border.all(
              color: tint.withValues(alpha: dark ? 0.28 : 0.12),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: r,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class Poster extends StatelessWidget {
  final String? path;
  final String? fallbackPath;
  final double? width;
  final double? height;
  final double radius;
  final String size;
  const Poster({
    super.key,
    required this.path,
    this.fallbackPath,
    this.width,
    this.height,
    this.radius = 16,
    this.size = 'w342',
  });

  @override
  Widget build(BuildContext context) {
    final localPath = path != null &&
        (path!.startsWith('file://') ||
            RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path!));
    if (localPath) {
      final file = path!.startsWith('file://')
          ? File.fromUri(Uri.parse(path!))
          : File(path!);
      if (!file.existsSync()) {
        return fallbackPath == null
            ? _placeholder(width, height)
            : Poster(
                path: fallbackPath,
                width: width,
                height: height,
                radius: radius,
                size: size);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallbackPath == null
                ? _placeholder(width, height)
                : Poster(
                    path: fallbackPath,
                    width: width,
                    height: height,
                    radius: radius,
                    size: size)),
      );
    }
    final displayPath = path ?? fallbackPath;
    final url = TmdbClient.img(displayPath, size: size);
    final placeholder = _placeholder(width, height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
              errorBuilder: (context, error, stack) {
                debugPrint('Errore caricamento immagine TMDB ($url): $error');
                return fallbackPath != null && fallbackPath != displayPath
                    ? Poster(
                        path: fallbackPath,
                        width: width,
                        height: height,
                        radius: radius,
                        size: size,
                      )
                    : placeholder;
              },
            ),
    );
  }

  Widget _placeholder(double? width, double? height) => Container(
        width: width,
        height: height,
        color: Colors.white.withValues(alpha: 0.06),
        child:
            const Icon(Icons.movie_outlined, size: 36, color: Colors.white38),
      );
}
