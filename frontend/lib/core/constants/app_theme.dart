import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Sprout AI Brand Palette ───────────────────────────────────────────────
  static const Color brown        = Color(0xFF5A2E1C); // Deep chocolate brown
  static const Color brownDark    = Color(0xFF3D1F0D); // Darker brown
  static const Color brownMid     = Color(0xFF7A4030); // Mid brown for hover
  static const Color gold         = Color(0xFFD4A017); // Warm mustard gold
  static const Color goldLight    = Color(0xFFF5E6A3); // Light gold tint
  static const Color goldSurface  = Color(0xFFFAF3DC); // Very light gold bg

  // ── Background / Surface ─────────────────────────────────────────────────
  static const Color background   = Color(0xFFF4EFE6); // Soft beige / warm cream
  static const Color surface      = Color(0xFFFFFFFF); // White card surface
  static const Color surfaceWarm  = Color(0xFFFAF7F2); // Warm off-white
  static const Color surfaceAlt   = Color(0xFFF0EAE0); // Slightly deeper beige

  // ── Borders & Dividers ───────────────────────────────────────────────────
  static const Color border       = Color(0xFFE3D9CC); // Warm beige border
  static const Color borderLight  = Color(0xFFEDE7DC); // Lighter border

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF2C1A0E); // Very dark brown
  static const Color textSecondary = Color(0xFF7A5C45); // Medium warm brown
  static const Color textHint      = Color(0xFFB59A80); // Light warm taupe

  // ── Semantic / Utility ───────────────────────────────────────────────────
  static const Color success      = Color(0xFF3D7A4F); // Forest green
  static const Color successLight = Color(0xFFE8F5EE);
  static const Color danger       = Color(0xFFB5362A);
  static const Color dangerLight  = Color(0xFFFDECEA);
  static const Color info         = Color(0xFF2B6CB0);
  static const Color infoLight    = Color(0xFFEBF4FF);

  // ── Nav Rail ─────────────────────────────────────────────────────────────
  static const Color navBg        = Color(0xFF5A2E1C); // Deep brown sidebar
  static const Color navActive    = Color(0xFFD4A017); // Gold active item
  static const Color navHover     = Color(0xFF7A4030); // Hover tint
  static const Color navText      = Color(0xFFF4EFE6); // Cream text on nav
  static const Color navTextMuted = Color(0xFFB59A80); // Muted nav label

  // ── Legacy aliases (keep existing code working) ──────────────────────────
  static const Color primary      = brown;
  static const Color primaryDark  = brownDark;
  static const Color primaryLight = goldSurface;
  static const Color secondary    = Color(0xFF3D7A4F);
  static const Color secondaryLight = Color(0xFFE8F5EE);
  static const Color accent       = gold;
  static const Color accentLight  = goldSurface;
  static const Color purple       = Color(0xFF6B4C8A);
  static const Color purpleLight  = Color(0xFFF2EDF8);

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brown,
        primary: brown,
        secondary: gold,
        tertiary: success,
        background: background,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge:  GoogleFonts.inter(fontWeight: FontWeight.w800, color: textPrimary, fontSize: 32),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 26),
        displaySmall:  GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 22),
        titleLarge:    GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 20),
        titleMedium:   GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 16),
        titleSmall:    GoogleFonts.inter(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 14),
        bodyLarge:     GoogleFonts.inter(color: textPrimary,   fontSize: 16, height: 1.6),
        bodyMedium:    GoogleFonts.inter(color: textSecondary, fontSize: 14, height: 1.5),
        bodySmall:     GoogleFonts.inter(color: textHint,      fontSize: 12),
        labelLarge:    GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brown,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: brown, width: 1.5),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brown, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: goldSurface,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: brownDark,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
