import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Accent {
  final String name;
  final Color v;
  final Color ink;
  const Accent(this.name, this.v, this.ink);
}

const List<Accent> kAccents = [
  Accent('VOLT',  Color(0xFFFF4D00), Color(0xFF2E0E00)),
  Accent('ACID',  Color(0xFFCCFF00), Color(0xFF333300)),
  Accent('SKY',   Color(0xFF00B3FF), Color(0xFF002233)),
  Accent('BLOOD', Color(0xFFE5002B), Color(0xFF300007)),
  Accent('LIME',  Color(0xFF2FE66A), Color(0xFF003014)),
];

class BrutalPalette {
  final Color ink;
  final Color paper;
  final Color accent;
  final Color accentInk;
  final bool isDark;

  const BrutalPalette({
    required this.ink,
    required this.paper,
    required this.accent,
    required this.accentInk,
    required this.isDark,
  });

  /// Accent-colored text painted on the paper background.
  /// In light mode, `accentInk` (dark variant) is readable on cream paper.
  /// In dark mode, it vanishes — so swap to the bright `accent`.
  Color get accentOnPaper => isDark ? accent : accentInk;

  static BrutalPalette fromTweaks({required bool dark, required Accent accent}) {
    return BrutalPalette(
      ink: dark ? const Color(0xFFD8D4C8) : const Color(0xFF0A0A0A),
      paper: dark ? const Color(0xFF131310) : const Color(0xFFF3F0E8),
      accent: accent.v,
      accentInk: accent.ink,
      isDark: dark,
    );
  }
}

TextStyle mono({
  required double size,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 0.3,
  Color? color,
  double? height,
}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
    height: height,
  );
}

/// Swap the wordmark SVG's hardcoded ink (`#0a0a0a`) and paper (`#F3F0E8`)
/// for the live palette colors. Accent fills in the SVG are left alone —
/// each accent has its own wordmark file.
String themedWordmark(String raw, BrutalPalette p) {
  String hex(Color c) {
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
  return raw
      .replaceAll(RegExp(r'#0a0a0a', caseSensitive: false), hex(p.ink))
      .replaceAll(RegExp(r'#F3F0E8', caseSensitive: false), hex(p.paper));
}
