import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../services/team_file_storage.dart';
import '../../theme/adaptive_field_theme.dart';

void showExportLoadingDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Calculating stats...'),
        ],
      ),
    ),
  );
}

Future<void> showExportResultDialog(
  BuildContext context, {
  required String text,
  required TeamFileStorage storage,
  void Function(String message)? onSaved,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Team'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Semantics(
            label: 'Team export text',
            child: ExcludeSemantics(
              child: SelectableText(text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Save exported team as a text file on this device',
          child: ExcludeSemantics(
            child: FilledButton(
              style: AdaptiveFieldTheme.filledButtonStyle(context),
              onPressed: () async {
                final file = await storage.saveTeam(text);
                final name = file.path.split(Platform.pathSeparator).last;
                onSaved?.call('Team saved as $name.');
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Saved as $name')));
                }
              },
              child: const Text('Save to Device'),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Copy exported team text to clipboard',
          child: ExcludeSemantics(
            child: FilledButton(
              style: AdaptiveFieldTheme.filledButtonStyle(context),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                }
              },
              child: const Text('Copy'),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Close export dialog',
          child: ExcludeSemantics(
            child: TextButton(
              style: AdaptiveFieldTheme.textButtonStyle(context),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ),
      ],
    ),
  );
}