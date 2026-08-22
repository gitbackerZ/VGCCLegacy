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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.92)),
          cursorColor: AdaptiveFieldTheme.cursorColor(context),
          decoration: AdaptiveFieldTheme.inputDecoration(context, '').copyWith(
            hintText: 'Paste exported team text here',
            hintStyle: TextStyle(color: AdaptiveFieldTheme.hintTextColor(context)),
          ),
        ),
      ),
      actions: [
        TextButton(
          style: AdaptiveFieldTheme.textButtonStyle(context),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: AdaptiveFieldTheme.filledButtonStyle(context),
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Parse'),
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
        TextButton(
          style: AdaptiveFieldTheme.textButtonStyle(context),
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: AdaptiveFieldTheme.filledButtonStyle(context),
          onPressed: () => Navigator.pop(context, 'add'),
          child: const Text('Add to Team'),
        ),
        FilledButton(
          style: AdaptiveFieldTheme.filledButtonStyle(context),
          onPressed: () => Navigator.pop(context, 'replace'),
          child: const Text('Replace Team'),
        ),
      ],
    ),
  );
}