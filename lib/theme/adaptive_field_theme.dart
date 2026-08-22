import 'package:flutter/material.dart';

/// Shared "soft high-contrast" styling used across the Team Builder screen
/// and its extracted panel/dialog widgets, so every file renders consistently
/// without duplicating the color math.
class AdaptiveFieldTheme {
  AdaptiveFieldTheme._();

  /// Soft field decoration: muted gray/white fills, readable but not glaring.
  static InputDecoration inputDecoration(BuildContext context, String labelText) {
    final cs = Theme.of(context).colorScheme;
    final softFill = Color.alphaBlend(
      cs.onSurface.withValues(alpha: 0.10),
      cs.surfaceContainerHighest,
    );
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.45)),
    );
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.90),
        fontSize: 13,
      ),
      floatingLabelStyle: TextStyle(
        color: cs.primary.withValues(alpha: 0.90),
      ),
      filled: true,
      fillColor: softFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: cs.primary.withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      errorStyle: TextStyle(color: cs.error),
    );
  }

  /// Dropdown menu background: soft elevated surface, not full inverse white/black.
  static Color dropdownMenuColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      cs.onSurface.withValues(alpha: 0.08),
      cs.surfaceContainerHigh,
    );
  }

  /// Body text color inside fields / dropdowns.
  static Color fieldTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.92);

  static Color hintTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

  static Color iconColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);

  static Color cursorColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.85);

  /// Primary actions — soft filled (primaryContainer), easier on the eyes.
  static ButtonStyle filledButtonStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.85),
      foregroundColor: cs.onPrimaryContainer,
      disabledBackgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
    );
  }

  /// Secondary / cancel — muted primary, not neon inverse.
  static ButtonStyle textButtonStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.styleFrom(
      foregroundColor: cs.primary.withValues(alpha: 0.90),
    );
  }

  /// Soft elevated surface used by autocomplete option lists.
  static Color optionsListColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      cs.onSurface.withValues(alpha: 0.08),
      cs.surfaceContainerHigh,
    );
  }
}