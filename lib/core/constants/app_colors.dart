import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette (Vibrant Warm Brand Orange)
  static const Color primary = Color(0xFFF05A22);
  static const Color primaryLight = Color(0xFFFF7A3D);
  static const Color primaryDark = Color(0xFFC73E0B);
  static const Color primaryContainer = Color(0xFFFFF0E9);

  // Secondary & Accent Palette (Royal Indigo & Warm Amber)
  static const Color secondary = Color(0xFF2563EB);
  static const Color secondaryLight = Color(0xFF3B82F6);
  static const Color secondaryDark = Color(0xFF1D4ED8);
  static const Color accent = Color(0xFFF59E0B);

  // Semantic Feedback Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successContainer = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningContainer = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorContainer = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);
  static const Color infoContainer = Color(0xFFE0F2FE);

  // Neutral & Surface Colors (Light Mode)
  static const Color background = Color(0xFFFAF8F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFEFE8E2);
  static const Color border = Color(0xFFE0D7D0);

  // Text Colors (Light Mode)
  static const Color textPrimary = Color(0xFF1C1917);
  static const Color textSecondary = Color(0xFF57534E);
  static const Color textMuted = Color(0xFFA8A29E);
  static const Color textLight = Color(0xFFFFFFFF);

  // Neutral & Surface Colors (Dark Mode)
  static const Color darkBackground = Color(0xFF141210);
  static const Color darkSurface = Color(0xFF1E1B18);
  static const Color darkCard = Color(0xFF1E1B18);
  static const Color darkDivider = Color(0xFF2E2925);
  static const Color darkBorder = Color(0xFF443D37);

  // Text Colors (Dark Mode)
  static const Color darkTextPrimary = Color(0xFFFAF7F5);
  static const Color darkTextSecondary = Color(0xFFD6CECA);
  static const Color darkTextMuted = Color(0xFF8C827A);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC73E0B), Color(0xFFF05A22), Color(0xFFFF7A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF05A22), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    colors: [Color(0xFFFAF8F5), Color(0xFFFFF2EB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
