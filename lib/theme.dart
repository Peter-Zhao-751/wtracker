import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberTheme {
  CyberTheme._();

  // ── Core palette ──
  static const Color bgDark = Color(0xFF080812);
  static const Color bgCard = Color(0xFF0e0e1e);
  static const Color bgCardLight = Color(0xFF151530);
  static const Color bgSurface = Color(0xFF1a1a35);

  static const Color neonCyan = Color(0xFF00e5ff);
  static const Color neonMagenta = Color(0xFFff0055);
  static const Color neonGreen = Color(0xFF00ff88);
  static const Color neonYellow = Color(0xFFffee00);
  static const Color neonPurple = Color(0xFFb44aff);

  static const Color textPrimary = Color(0xFFe8e8f8);
  static const Color textSecondary = Color(0xFF8888aa);
  static const Color textMuted = Color(0xFF4a4a6a);

  // ── Gradients ──
  static const LinearGradient accentGradient = LinearGradient(
    colors: [neonCyan, neonMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient chartGradient = LinearGradient(
    colors: [neonCyan, Color(0xFF0088aa)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Card decoration ──
  static BoxDecoration cardDecoration({
    Color glowColor = neonCyan,
    double glowOpacity = 0.08,
    double borderOpacity = 0.15,
  }) {
    return BoxDecoration(
      color: bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: glowColor.withValues(alpha: borderOpacity),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: glowOpacity),
          blurRadius: 20,
          spreadRadius: -2,
        ),
      ],
    );
  }

  // ── Theme data ──
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonMagenta,
        surface: bgCard,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textMuted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonCyan, width: 1.5),
        ),
        hintStyle: GoogleFonts.rajdhani(color: textMuted, fontSize: 15),
        labelStyle: GoogleFonts.rajdhani(color: textSecondary, fontSize: 14),
      ),
    );
  }

  // ── Text styles ──
  static TextStyle scoreDisplay = GoogleFonts.orbitron(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: neonCyan,
    letterSpacing: 2,
  );

  static TextStyle statValue = GoogleFonts.orbitron(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle statLabel = GoogleFonts.rajdhani(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 1.5,
  );

  static TextStyle sectionTitle = GoogleFonts.orbitron(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 2,
  );

  static TextStyle cardTitle = GoogleFonts.rajdhani(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle cardBody = GoogleFonts.rajdhani(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle chipText = GoogleFonts.orbitron(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
  );
}
