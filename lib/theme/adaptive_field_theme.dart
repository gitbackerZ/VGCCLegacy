import 'package:flutter/material.dart';

/// Shared "gray, device-default" styling used across the Team Builder screen
/// and its extracted panel/dialog widgets. Search fields, input containers,
/// toolbars, and dialog action buttons all use a flat gray that adapts to
/// light/dark mode, instead of theme-primary-derived tints.
class AdaptiveFieldTheme {
  AdaptiveFieldTheme._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Flat gray fill for text fields / search bars / input containers.
  static Color fieldFillColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade200;

  /// Flat gray for toolbars and panel containers (slightly different shade
  /// so nested containers stay visually distinct from fields).
  static Color containerColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade900 : Colors.grey.shade100;

  /// Flat gray background for dialog action buttons.
  static Color buttonBackgroundColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade700 : Colors.grey.shade300;

  static InputDecoration inputDecoration(BuildContext context, String labelText) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade500),
    );
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
      filled: true,
      fillColor: fieldFillColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade600, width: 1.5),
      ),
      errorStyle: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }

  static Color dropdownMenuColor(BuildContext context) => fieldFillColor(context);

  static Color fieldTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color hintTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

  static Color iconColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);

  static Color cursorColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Primary dialog action button — flat gray, device-default text color.
  static ButtonStyle filledButtonStyle(BuildContext context) {
    return FilledButton.styleFrom(
      backgroundColor: buttonBackgroundColor(context),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
      disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
    );
  }

  /// Secondary / cancel dialog action button.
  static ButtonStyle textButtonStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// Soft elevated surface used by autocomplete option lists.
  static Color optionsListColor(BuildContext context) => containerColor(context);
}