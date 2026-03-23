import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color clay = Color(0xFFD97D55);
  static const Color beige = Color(0xFFF4E9D7);
  static const Color sage = Color(0xFFB8C4A9);
  static const Color mistBlue = Color(0xFF6FA4AF);
  static const Color _background = Color(0xFFF8F0E3);
  static const Color _surface = Color(0xFFFFF8EE);
  static const Color _onSurface = Color(0xFF2C2925);
  static const Color _onSurfaceVariant = Color(0xFF6B665E);

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: clay,
          brightness: Brightness.light,
        ).copyWith(
          primary: clay,
          onPrimary: Colors.white,
          secondary: mistBlue,
          onSecondary: Colors.white,
          tertiary: sage,
          onTertiary: const Color(0xFF28321F),
          surface: _surface,
          onSurface: _onSurface,
          onSurfaceVariant: _onSurfaceVariant,
          surfaceContainerHighest: const Color(0xFFE7DDCC),
          primaryContainer: const Color(0xFFF0BB9F),
          onPrimaryContainer: const Color(0xFF4D2712),
          secondaryContainer: const Color(0xFFC8DEE2),
          onSecondaryContainer: const Color(0xFF183D43),
          outline: const Color(0xFFC5B8A5),
          error: const Color(0xFFB93A2E),
          onError: Colors.white,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          textStyle: const TextStyle(
            color: _onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
