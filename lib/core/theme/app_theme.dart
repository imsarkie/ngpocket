import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color clay = Color(0xFFD97D55);
  static const Color beige = Color(0xFFF4E9D7);
  static const Color sage = Color(0xFFB8C4A9);
  static const Color mistBlue = Color(0xFF6FA4AF);
  static const Color _background = beige; // #F4E9D7 — exact palette beige
  static const Color _surface = Color(0xFFFAF1E4);
  static const Color _onSurface = Color(0xFF2C2925);
  static const Color _onSurfaceVariant = Color(0xFF6B665E);

  // Dark palette — warm charcoal background complementing the clay brand
  static const Color _darkBackground = Color(0xFF1C1A17);
  static const Color _darkSurface = Color(0xFF252219);
  static const Color _darkOnSurface = Color(0xFFEDE4D5);
  static const Color _darkOnSurfaceVariant = Color(0xFFA8A09A);

  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData light() => lightTheme;
  static ThemeData dark() => darkTheme;

  static ThemeData _buildDarkTheme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: clay,
          brightness: Brightness.dark,
        ).copyWith(
          primary: clay,
          onPrimary: Colors.white,
          secondary: mistBlue,
          onSecondary: Colors.white,
          tertiary: sage,
          onTertiary: const Color(0xFF28321F),
          surface: _darkSurface,
          onSurface: _darkOnSurface,
          onSurfaceVariant: _darkOnSurfaceVariant,
          surfaceContainerHighest: const Color(0xFF2E2B25),
          primaryContainer: const Color(0xFF4D2712),
          onPrimaryContainer: const Color(0xFFF0BB9F),
          secondaryContainer: const Color(0xFF183D43),
          onSecondaryContainer: const Color(0xFFC8DEE2),
          outline: const Color(0xFF5C5650),
          error: const Color(0xFFFF6B5E),
          onError: const Color(0xFF1C0500),
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
        bodyLarge: uiTextTheme.bodyLarge?.copyWith(height: 1.35),
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        shadowColor: Color(0x40000000),
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
        backgroundColor: _darkBackground,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          textStyle: const TextStyle(
            color: _darkOnSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
          TargetPlatform.linux: _FadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadePageTransitionsBuilder(),
          TargetPlatform.windows: _FadePageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData _buildLightTheme() {
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
          TargetPlatform.linux: _FadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadePageTransitionsBuilder(),
          TargetPlatform.windows: _FadePageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    );
    return FadeTransition(opacity: fadeIn, child: child);
  }
}
