import 'package:flutter/material.dart';

class AppColors {
  /// Page background.
  static const paper = Color(0xFFFBF8F2);

  static const paperDeep = Color(0xFFE8DFD2);

  /// Body text. Reads on white and on [paper].
  static const body = Color(0xFF1F1B16);
  static const ink = body;

  /// Summary lines, darker than [meta].
  static const summary = Color(0xFF3F3A33);

  /// Meta text: minutes, captions, secondary labels.
  static const meta = Color(0xFF5C554B);
  static const inkMuted = meta;

  static const olive = Color(0xFF3E5C4B);
  static const oliveSoft = Color(0xFFE3EEE6);
  static const verse = Color(0xFFE5EFE7);

  /// Verse references on white, paper, and the verse card.
  static const verseRef = Color(0xFFA8291F);

  /// Decorative rule. Not a text color.
  static const line = Color(0xFFC4A574);

  static const card = Color(0xFFFFFFFF);
  static const danger = Color(0xFF8C3A32);

  static const chipInk = Color(0xFF4A3A00);
  static const chipFill = Color(0xFFF1EBD8);

  static const lessonNavy = Color(0xFF1E1A3C);
  static const lessonGold = Color(0xFFF6D84C);
  static const lessonRef = Color(0xFFE9E4FF);

  static const noteFill = Color(0xFFF8E7A2);
  static const notePaper = Color(0xFFFFF6CC);
  static const noteInk = chipInk;

  /// Hand-lettered banner ink on the kraft ground ([line]).
  static const kraftInk = Color(0xFF3A2A1C);

  static const posterGold = Color(0xFFF2C94C);
  static const posterInk = Color(0xFF2A2418);
  static const posterRed = Color(0xFF8E1A12);

  /// Bottom of the photo-banner scrim. White type sits on this.
  static const scrim = Color(0xFF14110E);

  static const night = Color(0xFF141210);
  static const nightRaised = Color(0xFF221E1B);
  static const nightInk = Color(0xFFF4EEE6);
  static const nightMuted = Color(0xFFB7AA9E);
  static const nightOlive = Color(0xFFD7C4A3);
  static const nightVerse = Color(0xFF2A332E);
  static const nightLine = Color(0xFF8C7350);
  static const nightSoft = Color(0xFF24302A);
  static const nightContainer = Color(0xFF2A2522);
  static const nightContainerHigh = Color(0xFF322C28);

  static Color readingRef(Brightness brightness) =>
      brightness == Brightness.dark ? nightOlive : verseRef;

  static Color summaryInk(Brightness brightness) =>
      brightness == Brightness.dark ? nightInk : summary;

  /// Mark for a note icon that sits on the page, not on [noteFill].
  static Color notedMark(Brightness brightness) =>
      brightness == Brightness.dark ? lessonGold : noteInk;
}

class AppTheme {
  static const serif = 'Source Serif 4';
  static const sans = 'Source Sans 3';

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.olive,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.nightOlive : AppColors.olive,
          onPrimary: isDark ? AppColors.night : Colors.white,
          surface: isDark ? AppColors.night : AppColors.paper,
          onSurface: isDark ? AppColors.nightInk : AppColors.body,
          onSurfaceVariant: isDark ? AppColors.nightMuted : AppColors.meta,
          secondary: isDark ? AppColors.nightLine : AppColors.line,
          onSecondary: isDark ? AppColors.night : AppColors.body,
          primaryContainer: isDark ? AppColors.nightSoft : AppColors.oliveSoft,
          onPrimaryContainer: isDark ? AppColors.nightInk : AppColors.body,
          secondaryContainer: isDark ? AppColors.nightSoft : AppColors.chipFill,
          onSecondaryContainer: isDark ? AppColors.nightInk : AppColors.chipInk,
          surfaceContainerLowest: isDark
              ? AppColors.nightRaised
              : AppColors.card,
          surfaceContainerLow: isDark ? AppColors.nightRaised : AppColors.paper,
          surfaceContainer: isDark ? AppColors.nightContainer : AppColors.card,
          surfaceContainerHigh: isDark
              ? AppColors.nightContainerHigh
              : AppColors.paperDeep,
          surfaceContainerHighest: isDark
              ? const Color(0xFF3A342E)
              : const Color(0xFFE4DDD2),
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
            color: scheme.onSurface,
          ),
          labelMedium: base.textTheme.labelMedium?.copyWith(
            fontFamily: sans,
            letterSpacing: 0.3,
            color: scheme.onSurfaceVariant,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontFamily: sans,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontFamily: serif,
            fontSize: 18,
            height: 1.55,
            color: scheme.onSurface,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontFamily: serif,
            fontSize: 16.5,
            height: 1.5,
            color: scheme.onSurface,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: serif,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: scheme.onSurface,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: serif,
            fontWeight: FontWeight.w600,
            height: 1.2,
            color: scheme.onSurface,
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
          text.labelMedium?.copyWith(
            fontFamily: sans,
            fontSize: 12,
            color: scheme.onSurface,
          ),
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
        backgroundColor: isDark ? AppColors.nightRaised : AppColors.chipFill,
        selectedColor: isDark ? AppColors.nightSoft : AppColors.chipFill,
        side: BorderSide(
          color: isDark ? const Color(0xFF3A342E) : AppColors.chipFill,
        ),
        labelStyle: text.labelLarge?.copyWith(
          fontFamily: sans,
          color: isDark ? AppColors.nightInk : AppColors.chipInk,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }
}
