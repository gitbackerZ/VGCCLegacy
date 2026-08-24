import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'dart:io' show Platform;
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
  final filenameController = TextEditingController(text: TeamFileStorage.defaultBaseName);

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Team'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Team export text',
                child: SelectableText(text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'File name for saved team',
                textField: true,
                child: TextField(
                  controller: filenameController,
                  style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context)),
                  cursorColor: AdaptiveFieldTheme.cursorColor(context),
                  decoration: AdaptiveFieldTheme.inputDecoration(context, 'File Name'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Save team as text',
          child: ExcludeSemantics(
            child: FilledButton(
              style: AdaptiveFieldTheme.filledButtonStyle(context),
              onPressed: () async {
                final file = await storage.saveTeam(text, filename: filenameController.text);
                final name = file.path.split(Platform.pathSeparator).last;
                onSaved?.call('Team saved as $name.');
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Saved as $name')));
                }
              },
              child: const Text('Save'),
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