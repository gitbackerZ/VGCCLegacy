import 'package:flutter/material.dart';

class AdaptiveFieldTheme {
  AdaptiveFieldTheme._();

  // ---- Pokéball card palette (fixed, not theme-adaptive) ----
  static const Color pokeballRed = Color(0xFFEE1515);
  static const Color pokeballDarkGray = Color(0xFF262626);
  static const Color headerText = Colors.white;
  static const Color bodyText = Colors.white;
  static const Color toolbarBg = Colors.white;
  static const Color toolbarText = Colors.black;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color fieldFillColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : Colors.grey.shade200;

  static Color containerColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade900 : Colors.grey.shade100;

  static Color buttonBackgroundColor(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade700 : Colors.grey.shade300;

  static InputDecoration inputDecoration(
    BuildContext context,
    String labelText, {
    bool alwaysFloatLabel = false,
  }) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade500),
    );
    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior:
          alwaysFloatLabel ? FloatingLabelBehavior.always : null,
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
  static Color fieldTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color hintTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
  static Color iconColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);
  static Color cursorColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  static ButtonStyle filledButtonStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: buttonBackgroundColor(context),
      foregroundColor: cs.onSurface,
      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
      disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
    );
  }

  static ButtonStyle textButtonStyle(BuildContext context) {
    return TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface);
  }

  static Color optionsListColor(BuildContext context) => containerColor(context);
}