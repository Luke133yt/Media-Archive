/// Formati proposti di default. L'utente può aggiungerne quanti ne vuole
/// scrivendo semplicemente il nome (es. "HD-DVD", "CED", "Video CD").
const defaultFormats = <String>[
  'Non Specificato',
  'DVD',
  'Blu-ray',
  'Blu-ray 4K',
  'HD-DVD',
  'VHS',
  'Video 2000',
  'Betamax',
  'Betacam',
  'Video8',
  'Hi8',
  'Super 8',
  '8mm',
  '16mm',
  '35mm',
  'CD Video',
  'Video CD',
  'LaserDisc',
  'File digitale',
];

const regionPresets = <String>[
  'PAL',
  'NTSC',
  'SECAM',
  'Region 0',
  'Region 1',
  'Region 2',
  'Region 3',
  'Region 4',
  'Region 5',
  'Region 6',
  'Region A',
  'Region B',
  'Region C',
];

enum FormatKind { disc, cassette, reel, generic }

class FormatStyle {
  final FormatKind kind;
  final int base; // colore principale ARGB
  final int accent; // colore anello / dettaglio
  final double scale; // dimensione relativa (LaserDisc è grande)
  const FormatStyle(this.kind, this.base, this.accent, [this.scale = 1]);
}

FormatStyle styleFor(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
  bool has(String s) => n.contains(s);

  if (has('blu') && (has('4k') || has('uhd'))) {
    return const FormatStyle(FormatKind.disc, 0xFF15181F, 0xFF2B6BFF);
  }
  if (has('blu') || has('bd')) {
    return const FormatStyle(FormatKind.disc, 0xFFB9C7D9, 0xFF1E88FF);
  }
  if (has('hd-dvd') || has('hddvd')) {
    return const FormatStyle(FormatKind.disc, 0xFFC9C9D1, 0xFFE53935);
  }
  if (has('laser')) {
    return const FormatStyle(FormatKind.disc, 0xFFD8D2B8, 0xFFB08D2B, 1);
  }
  if (has('dvd')) {
    return const FormatStyle(FormatKind.disc, 0xFFD3D7DE, 0xFF9AA4B5);
  }
  if (has('cd') || has('vcd')) {
    return const FormatStyle(FormatKind.disc, 0xFFC8CCD6, 0xFFB0B7C6);
  }
  if (has('vhs') ||
      has('video2000') ||
      has('v2000') ||
      has('betamax') ||
      has('beta') ||
      has('video8') ||
      has('hi8') ||
      has('vcr')) {
    final color = has('beta')
        ? 0xFF3F51B5
        : has('video8') || has('hi8')
            ? 0xFF26A69A
            : has('2000')
                ? 0xFF8E6E53
                : 0xFF2A2D36;
    return FormatStyle(FormatKind.cassette, color, 0xFFEFEFEF);
  }
  if (has('super8') ||
      has('8mm') ||
      has('16mm') ||
      has('35mm') ||
      has('film') ||
      has('pellicola')) {
    return const FormatStyle(FormatKind.reel, 0xFF5A5F6B, 0xFFE0A93B);
  }
  return const FormatStyle(FormatKind.generic, 0xFF6C7A96, 0xFFB7C3DB);
}

String languageNameFromCode(String code) {
  const m = {
    'it': 'Italiano',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'pt': 'Português',
    'ja': '日本語',
  };
  final c = code.toLowerCase().split(RegExp(r'[-_]')).first;
  return m[c] ?? code;
}
