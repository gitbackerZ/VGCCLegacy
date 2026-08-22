import 'package:flutter/material.dart';
import '../../theme/adaptive_field_theme.dart';

/// Shows the paste-text dialog and returns the raw pasted text (or null if
/// cancelled).
Future<String?> showImportPasteDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import Team'),
      content: Semantics(
        label: 'Paste team text here',
        textField: true,
        child: TextField(
          controller: controller,
          maxLines: 10,
          style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context)),
          cursorColor: AdaptiveFieldTheme.cursorColor(context),
          decoration: AdaptiveFieldTheme.inputDecoration(context, '').copyWith(
            hintText: 'Paste exported team text here',
            hintStyle: TextStyle(color: AdaptiveFieldTheme.hintTextColor(context)),
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Cancel import',
          child: TextButton(
            style: AdaptiveFieldTheme.textButtonStyle(context),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        Semantics(
          button: true,
          label: 'Parse pasted team text',
          child: FilledButton(
            style: AdaptiveFieldTheme.filledButtonStyle(context),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Parse'),
          ),
        ),
      ],
    ),
  );
}

/// Shows the add/replace/cancel mode-selection dialog. Returns 'add',
/// 'replace', or 'cancel'/null.
Future<String?> showImportModeDialog(BuildContext context, {required int parsedCount}) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import Mode'),
      content: Text('Found $parsedCount Pokémon in the pasted text. How should this be applied?'),
      actions: [
        Semantics(
          button: true,
          label: 'Cancel import',
          child: TextButton(
            style: AdaptiveFieldTheme.textButtonStyle(context),
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
        ),
        Semantics(
          button: true,
          label: 'Add $parsedCount imported Pokémon to current team',
          child: FilledButton(
            style: AdaptiveFieldTheme.filledButtonStyle(context),
            onPressed: () => Navigator.pop(context, 'add'),
            child: const Text('Add to Team'),
          ),
        ),
        Semantics(
          button: true,
          label: 'Replace current team with $parsedCount imported Pokémon',
          child: FilledButton(
            style: AdaptiveFieldTheme.filledButtonStyle(context),
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Replace Team'),
          ),
        ),
      ],
    ),
  );
}