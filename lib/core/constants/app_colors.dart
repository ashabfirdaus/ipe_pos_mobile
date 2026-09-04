import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette (Vibrant Emerald & Forest Green from Logo)
  static const Color primary = Color(0xFF1E8455);
  static const Color primaryLight = Color(0xFF2BB373);
  static const Color primaryDark = Color(0xFF14633E);
  static const Color primaryContainer = Color(0xFFE7F7EE);

  // Secondary & Accent Palette (Warm Amber & Gold from Logo)
  static const Color secondary = Color(0xFFE5812B);
  static const Color secondaryLight = Color(0xFFFAA723);
  static const Color secondaryDark = Color(0xFFC86918);
  static const Color accent = Color(0xFFFAA723);

  // Semantic Feedback Colors
  static const Color success = Color(0xFF1E8455);
  static const Color successLight = Color(0xFFE7F7EE);
  static const Color successContainer = Color(0xFFE7F7EE);

  static const Color warning = Color(0xFFE5812B);
  static const Color warningLight = Color(0xFFFEF3E8);
  static const Color warningContainer = Color(0xFFFEF3E8);

  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorContainer = Color(0xFFFFEBEE);

  static const Color info = Color(0xFF0288D1);
  static const Color infoLight = Color(0xFFE1F5FE);
  static const Color infoContainer = Color(0xFFE1F5FE);

  // Neutral & Surface Colors (Light Mode)
  static const Color background = Color(0xFFF7FAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE2EBE5);
  static const Color border = Color(0xFFCFDDD4);

  // Text Colors (Light Mode)
  static const Color textPrimary = Color(0xFF132A1F);
  static const Color textSecondary = Color(0xFF4A6357);
  static const Color textMuted = Color(0xFF8BA598);
  static const Color textLight = Color(0xFFFFFFFF);

  // Neutral & Surface Colors (Dark Mode)
  static const Color darkBackground = Color(0xFF0F1B15);
  static const Color darkSurface = Color(0xFF182B21);
  static const Color darkCard = Color(0xFF182B21);
  static const Color darkDivider = Color(0xFF274234);
  static const Color darkBorder = Color(0xFF355745);

  // Text Colors (Dark Mode)
  static const Color darkTextPrimary = Color(0xFFF1F8F4);
  static const Color darkTextSecondary = Color(0xFF9FBDB0);
  static const Color darkTextMuted = Color(0xFF6B8A7D);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF14633E), Color(0xFF1E8455), Color(0xFF2BB373)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE5812B), Color(0xFFFAA723)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF7FAF8), Color(0xFFEDF6F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
