import 'package:flutter/material.dart';
import '../../theme/adaptive_field_theme.dart';

/// Returns true if the user confirmed removal, false/null otherwise.
Future<bool?> showRemoveConfirmDialog(BuildContext context, {required String name}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove Pokémon?'),
      content: Text('Remove $name from your team? This cannot be undone.'),
      actions: [
        Semantics(
          button: true,
          label: 'Cancel removing $name',
          child: TextButton(
            style: AdaptiveFieldTheme.textButtonStyle(context),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ),
        Semantics(
          button: true,
          label: 'Confirm removal of $name from team',
          child: FilledButton(
            style: AdaptiveFieldTheme.filledButtonStyle(context),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove $name'),
          ),
        ),
      ],
    ),
  );
}