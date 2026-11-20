import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours from the Stitch design system, used across all screens.
class AppColors {
  static const background = Color(0xFFFFF8F4);
  static const surface = Colors.white;
  static const sand = Color(0xFFF4DFCB);
  static const sandLight = Color(0xFFFAE5D1);
  static const ink = Color(0xFF241A0E);
  static const inkSoft = Color(0xFF4C4546);
  static const muted = Color(0xFF7E7576);
  static const outline = Color(0xFFCFC4C5);
  static const border = Color(0xFFEBD7C3);
  static const error = Color(0xFFBA1A1A);
  static const errorBg = Color(0xFFFFDAD6);
  static const errorText = Color(0xFF93000A);
}

class AppText {
  static TextStyle brand() => GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.5, color: AppColors.ink);
  static TextStyle title(double size) =>
      GoogleFonts.notoSerif(fontSize: size, fontWeight: FontWeight.w400, color: AppColors.ink);
  static TextStyle label() => GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2, color: AppColors.muted);
  static TextStyle body({double size = 14, Color color = AppColors.ink, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight, height: 1.45);
}

final cardShadow = [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6))];

ButtonStyle primaryButton() => ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.outline,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    );

ButtonStyle secondaryButton() => ElevatedButton.styleFrom(
      backgroundColor: AppColors.sand,
      foregroundColor: Colors.black,
      disabledBackgroundColor: AppColors.sandLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    );

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Color(0xFF5D5F5B),
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.notoSerif(fontSize: 42, height: 1.1, color: AppColors.ink),
        headlineMedium: GoogleFonts.notoSerif(fontSize: 28, height: 1.2, color: AppColors.ink),
        titleSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
        bodyMedium: GoogleFonts.inter(fontSize: 16, height: 1.6, color: AppColors.ink),
        labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
      ),
    );
