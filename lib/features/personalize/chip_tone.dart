import 'package:flutter/material.dart';

/// Colors for a Personalize chip in the selected and resting states.
///
/// Backgrounds and labels come from the theme so light, dark, and the
/// system dark theme stay readable together.
class ChipTone {
  const ChipTone({
    required this.background,
    required this.foreground,
    required this.border,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color accent;

  static ChipTone resolve(ColorScheme scheme, {required bool selected}) {
    if (selected) {
      return ChipTone(
        background: scheme.primaryContainer,
        foreground: scheme.onSurface,
        border: scheme.primary,
        accent: scheme.primary,
      );
    }
    return ChipTone(
      background: scheme.surfaceContainerLowest,
      foreground: scheme.onSurface,
      border: scheme.outline,
      accent: scheme.onSurfaceVariant,
    );
  }
}
