
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const accent = Color(0xFF2563EB);
  static const accentHover = Color(0xFF1D4ED8);
  static const accentMuted = Color(0x1F2563EB);
  static const bgBase = Color(0xFFF4F6FA);
  static const bgCard = Color(0xFFFFFFFF);
  static const bgSidebar = Color(0xFFF0F2F8);
  static const bgInput = Color(0xFFFFFFFF);
  static const borderColor = Color(0xFFE2E6EF);
  static const textPrimary = Color(0xFF0D1117);
  static const textSecondary = Color(0xFF4B5563);
  static const textTertiary = Color(0xFF9CA3AF);
  static const badgeGreenBg = Color(0xFFDCFCE7);
  static const badgeGreenTxt = Color(0xFF166534);
  static const badgeRedBg = Color(0xFFFEE2E2);
  static const badgeRedTxt = Color(0xFF991B1B);
  static const badgeBlueBg = Color(0xFFDBEAFE);
  static const badgeBlueTxt = Color(0xFF1E40AF);
  static const badgeAmberBg = Color(0xFFFEF3C7);
  static const badgeAmberTxt = Color(0xFF92400E);
  static const badgePurpleBg = Color(0xFFF3E8FF);
  static const badgePurpleTxt = Color(0xFF6B21A8);
  static const alertOkBg = Color(0xFFF0FDF4);
  static const alertOkTxt = Color(0xFF166534);
  static const alertOkBdr = Color(0xFF86EFAC);
  static const alertErrBg = Color(0xFFFEF2F2);
  static const alertErrTxt = Color(0xFF991B1B);
  static const alertErrBdr = Color(0xFFFCA5A5);
  static const emergencyBg = Color(0xFFFEF2F2);
  static const emergencyBdr = Color(0xFFFCA5A5);
  static const emergencyTxt = Color(0xFF991B1B);
  static const emergencyIco = Color(0xFFB91C1C);

  static const darkAccent = Color(0xFF3B82F6);
  static const darkAccentHover = Color(0xFF60A5FA);
  static const darkAccentMuted = Color(0x263B82F6);
  static const darkBgBase = Color(0xFF000000);
  static const darkBgCard = Color(0xFF0D0D0D);
  static const darkBgSidebar = Color(0xFF080808);
  static const darkBgInput = Color(0xFF111111);
  static const darkBorderColor = Color(0xFF1E1E1E);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextTertiary = Color(0xFF4B5563);
  static const darkBadgeGreenBg = Color(0x6614532D);
  static const darkBadgeGreenTxt = Color(0xFF4ADE80);
  static const darkBadgeRedBg = Color(0x667F1D1D);
  static const darkBadgeRedTxt = Color(0xFFF87171);
  static const darkBadgeBlueBg = Color(0x661E3A8A);
  static const darkBadgeBlueTxt = Color(0xFF93C5FD);
  static const darkBadgeAmberBg = Color(0x6678350F);
  static const darkBadgeAmberTxt = Color(0xFFFCD34D);
  static const darkBadgePurpleBg = Color(0x664C1D95);
  static const darkBadgePurpleTxt = Color(0xFFC4B5FD);
  static const darkEmergencyBg = Color(0x337F1D1D);
  static const darkEmergencyBdr = Color(0x59F87171);
  static const darkEmergencyTxt = Color(0xFFFCA5A5);
  static const darkEmergencyIco = Color(0xFFF87171);

  static const Gradient logoGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
  );
  static const Gradient darkLogoGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
  );
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true, brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.light, surface: AppColors.bgCard),
    scaffoldBackgroundColor: AppColors.bgBase, cardColor: AppColors.bgCard, dividerColor: AppColors.borderColor,
    textTheme: _textTheme(AppColors.textPrimary),
    appBarTheme: AppBarTheme(backgroundColor: AppColors.bgCard, foregroundColor: AppColors.textPrimary, elevation: 0, surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.2)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), elevation: 0)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.bgInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: GoogleFonts.dmSans(color: AppColors.textTertiary, fontSize: 13.5),
      labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.05)),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.darkAccent, brightness: Brightness.dark, surface: AppColors.darkBgCard),
    scaffoldBackgroundColor: AppColors.darkBgBase, cardColor: AppColors.darkBgCard, dividerColor: AppColors.darkBorderColor,
    textTheme: _textTheme(AppColors.darkTextPrimary),
    appBarTheme: AppBarTheme(backgroundColor: AppColors.darkBgCard, foregroundColor: AppColors.darkTextPrimary, elevation: 0, surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary, letterSpacing: -0.2)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.darkAccent, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), elevation: 0)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.darkBgInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.darkBorderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.darkBorderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.darkAccent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: GoogleFonts.dmSans(color: AppColors.darkTextTertiary, fontSize: 13.5),
      labelStyle: GoogleFonts.dmSans(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.05)),
  );

  static TextTheme _textTheme(Color base) => TextTheme(
    displayLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: base, letterSpacing: -0.5),
    displayMedium: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w600, color: base, letterSpacing: -0.4),
    headlineLarge: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: base, letterSpacing: -0.3),
    headlineMedium: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: base, letterSpacing: -0.3),
    headlineSmall: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: base, letterSpacing: -0.2),
    titleLarge: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: base),
    titleMedium: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: base),
    bodyLarge: GoogleFonts.dmSans(fontSize: 14, color: base),
    bodyMedium: GoogleFonts.dmSans(fontSize: 13, color: base),
    bodySmall: GoogleFonts.dmSans(fontSize: 11.5, color: base.withOpacity(0.7)),
    labelLarge: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: base),
    labelMedium: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: base, letterSpacing: 0.05),
    labelSmall: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: base, letterSpacing: 0.08),
  );
}
