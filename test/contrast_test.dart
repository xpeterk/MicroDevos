import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/theme/app_theme.dart';

/// WCAG relative luminance, then contrast ratio.
double contrastRatio(Color foreground, Color background) {
  final lighter = _luminance(foreground);
  final darker = _luminance(background);
  final hi = lighter > darker ? lighter : darker;
  final lo = lighter > darker ? darker : lighter;
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

void main() {
  test('theme text and surface pairs meet WCAG AA 4.5:1', () {
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;
    final pairs = <String, (Color, Color)>{
      'light body on page': (light.onSurface, light.surface),
      'light body on card': (light.onSurface, light.surfaceContainerLowest),
      'light body on quote': (light.onSurface, light.primaryContainer),
      'light body on low container': (
        light.onSurface,
        light.surfaceContainerLow,
      ),
      'light body on container': (light.onSurface, light.surfaceContainer),
      'light meta on page': (light.onSurfaceVariant, light.surface),
      'light meta on card': (
        light.onSurfaceVariant,
        light.surfaceContainerLowest,
      ),
      'light meta on low container': (
        light.onSurfaceVariant,
        light.surfaceContainerLow,
      ),
      'light label on primary': (light.onPrimary, light.primary),
      'light primary on page': (light.primary, light.surface),
      'light primary on card': (light.primary, light.surfaceContainerLowest),
      'light chip': (light.onSecondaryContainer, light.secondaryContainer),
      'light on primary container': (
        light.onPrimaryContainer,
        light.primaryContainer,
      ),
      'dark body on page': (dark.onSurface, dark.surface),
      'dark body on card': (dark.onSurface, dark.surfaceContainerLowest),
      'dark body on quote': (dark.onSurface, dark.primaryContainer),
      'dark body on container': (dark.onSurface, dark.surfaceContainer),
      'dark body on high container': (
        dark.onSurface,
        dark.surfaceContainerHigh,
      ),
      'dark meta on page': (dark.onSurfaceVariant, dark.surface),
      'dark meta on card': (dark.onSurfaceVariant, dark.surfaceContainerLowest),
      'dark meta on container': (dark.onSurfaceVariant, dark.surfaceContainer),
      'dark meta on high container': (
        dark.onSurfaceVariant,
        dark.surfaceContainerHigh,
      ),
      'dark label on primary': (dark.onPrimary, dark.primary),
      'dark primary on page': (dark.primary, dark.surface),
      'dark primary on card': (dark.primary, dark.surfaceContainerLowest),
      'dark chip': (dark.onSecondaryContainer, dark.secondaryContainer),
      'dark ref on page': (
        AppColors.readingRef(Brightness.dark),
        AppColors.night,
      ),
      'dark ref on verse card': (
        AppColors.readingRef(Brightness.dark),
        AppColors.nightVerse,
      ),
      'body on white': (AppColors.body, AppColors.card),
      'body on page': (AppColors.body, AppColors.paper),
      'summary on white': (AppColors.summary, Colors.white),
      'summary on page': (AppColors.summary, AppColors.paper),
      'meta on page': (AppColors.meta, AppColors.paper),
      'meta on white': (AppColors.meta, Colors.white),
      'verse ref on white': (AppColors.verseRef, Colors.white),
      'verse ref on page': (AppColors.verseRef, AppColors.paper),
      'verse ref on verse card': (AppColors.verseRef, AppColors.verse),
      'chips': (AppColors.chipInk, AppColors.chipFill),
      'lesson gold': (AppColors.lessonGold, AppColors.lessonNavy),
      'lesson white': (Colors.white, AppColors.lessonNavy),
      'lesson ref': (AppColors.lessonRef, AppColors.lessonNavy),
      'note ink': (AppColors.noteInk, AppColors.noteFill),
      'body on note': (AppColors.body, AppColors.noteFill),
      'meta on note': (AppColors.meta, AppColors.noteFill),
      'body on note paper': (AppColors.body, AppColors.notePaper),
      'kraft title': (AppColors.kraftInk, AppColors.line),
      'poster red': (AppColors.posterRed, AppColors.posterGold),
      'poster ink': (AppColors.posterInk, AppColors.posterGold),
      'white on photo scrim': (Colors.white, AppColors.scrim),
    };

    expect(light.onSurface, AppColors.body);
    expect(light.surface, AppColors.paper);
    expect(light.onSurfaceVariant, AppColors.meta);
    expect(light.surfaceContainerLowest, AppColors.card);
    expect(light.onSecondaryContainer, AppColors.chipInk);
    expect(light.secondaryContainer, AppColors.chipFill);
    expect(dark.onSurface, AppColors.nightInk);
    expect(dark.surface, AppColors.night);
    expect(dark.onSurfaceVariant, AppColors.nightMuted);

    final failures = <String>[];
    for (final entry in pairs.entries) {
      final ratio = contrastRatio(entry.value.$1, entry.value.$2);
      if (ratio < 4.5) {
        failures.add('${entry.key} is ${ratio.toStringAsFixed(2)}:1');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
