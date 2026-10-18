import 'package:flutter/material.dart';

class AppColors {
  static const paper = Color(0xFFF6F1E8);
  static const paperDeep = Color(0xFFE8DFD2);
  static const ink = Color(0xFF2A2420);
  static const inkMuted = Color(0xFF6E645C);
  static const olive = Color(0xFF3E5C4B);
  static const oliveSoft = Color(0xFFE3EEE6);
  static const verse = Color(0xFFE5EFE7);
  static const line = Color(0xFFC4A574);
  static const card = Color(0xFFFFFCF8);
  static const danger = Color(0xFF8C3A32);

  static const night = Color(0xFF141210);
  static const nightRaised = Color(0xFF221E1B);
  static const nightInk = Color(0xFFF4EEE6);
  static const nightMuted = Color(0xFFB7AA9E);
  static const nightOlive = Color(0xFFD7C4A3);
  static const nightVerse = Color(0xFF2A332E);
  static const nightLine = Color(0xFF8C7350);
  static const nightSoft = Color(0xFF24302A);
}

class AppTheme {
  static const serif = 'Source Serif 4';
  static const sans = 'Source Sans 3';

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.olive,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.nightOlive : AppColors.olive,
      onPrimary: isDark ? AppColors.night : Colors.white,
      surface: isDark ? AppColors.night : AppColors.paper,
      onSurface: isDark ? AppColors.nightInk : AppColors.ink,
      onSurfaceVariant: isDark ? AppColors.nightMuted : AppColors.inkMuted,
      secondary: isDark ? AppColors.nightLine : AppColors.line,
      primaryContainer: isDark ? AppColors.nightSoft : AppColors.oliveSoft,
      surfaceContainerLowest: isDark ? AppColors.nightRaised : AppColors.card,
      outline: isDark ? const Color(0xFF3A342E) : AppColors.paperDeep,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );
    final text = base.textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: serif,
        )
        .copyWith(
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontFamily: sans,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelMedium: base.textTheme.labelMedium?.copyWith(
            fontFamily: sans,
            letterSpacing: 0.3,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontFamily: sans,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontFamily: serif,
            fontSize: 18,
            height: 1.55,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontFamily: serif,
            fontSize: 16.5,
            height: 1.5,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: serif,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: serif,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleSmall?.copyWith(
          fontFamily: sans,
          letterSpacing: 1.4,
          fontSize: 13,
          color: scheme.primary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          text.labelMedium?.copyWith(fontFamily: sans, fontSize: 12),
        ),
      ),
      dividerColor: scheme.outline,
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outline),
        labelStyle: text.labelLarge?.copyWith(fontFamily: sans),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }
}
