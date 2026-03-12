import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _lightBackground = Color(0xFFF4F1EA);
  static const _lightSurface = Color(0xFFFFFCF6);
  static const _darkBackground = Color(0xFF151A1D);
  static const _darkSurface = Color(0xFF1D2529);

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0F766E),
      onPrimary: Colors.white,
      secondary: Color(0xFF155E75),
      onSecondary: Colors.white,
      error: Color(0xFFB91C1C),
      onError: Colors.white,
      surface: _lightSurface,
      onSurface: Color(0xFF101214),
      onSurfaceVariant: Color(0xFF4A545B),
      outline: Color(0xFFB9C2C8),
      shadow: Color(0x22000000),
      scrim: Color(0x99000000),
      inverseSurface: Color(0xFF212A30),
      onInverseSurface: Color(0xFFF6FAFC),
      inversePrimary: Color(0xFF22A49B),
      surfaceContainerHighest: Color(0xFFE7ECEF),
      onTertiary: Colors.white,
      tertiary: Color(0xFF8A6433),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _lightBackground,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final uiTextTheme = GoogleFonts.dmSansTextTheme(base.textTheme);
    final readingFont = GoogleFonts.sourceSerif4TextTheme(base.textTheme);

    return base.copyWith(
      textTheme: uiTextTheme.copyWith(
        displayLarge: readingFont.displayLarge,
        displayMedium: readingFont.displayMedium,
        displaySmall: readingFont.displaySmall,
        headlineLarge: readingFont.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: readingFont.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: uiTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: uiTextTheme.bodyLarge?.copyWith(height: 1.35),
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        shadowColor: Color(0x24000000),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        elevation: 12,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF101214),
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          textStyle: const TextStyle(
            color: Color(0xFF101214),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF39C2B8),
      onPrimary: Color(0xFF032C28),
      secondary: Color(0xFF73C2E0),
      onSecondary: Color(0xFF00293A),
      error: Color(0xFFFF8B8B),
      onError: Color(0xFF450707),
      surface: _darkSurface,
      onSurface: Color(0xFFE5EDF0),
      onSurfaceVariant: Color(0xFFB3C0C6),
      outline: Color(0xFF425058),
      shadow: Color(0x99000000),
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFEAF4F7),
      onInverseSurface: Color(0xFF131A1D),
      inversePrimary: Color(0xFF0A766F),
      surfaceContainerHighest: Color(0xFF2A343B),
      onTertiary: Color(0xFF1D1405),
      tertiary: Color(0xFFDCB27A),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackground,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final uiTextTheme = GoogleFonts.dmSansTextTheme(base.textTheme);
    final readingFont = GoogleFonts.sourceSerif4TextTheme(base.textTheme);

    return base.copyWith(
      textTheme: uiTextTheme.copyWith(
        displayLarge: readingFont.displayLarge,
        displayMedium: readingFont.displayMedium,
        displaySmall: readingFont.displaySmall,
        headlineLarge: readingFont.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: readingFont.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: uiTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: uiTextTheme.bodyLarge?.copyWith(height: 1.4),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shadowColor: Color(0x99000000),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        elevation: 12,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE5EDF0),
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          textStyle: const TextStyle(
            color: Color(0xFFE5EDF0),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
