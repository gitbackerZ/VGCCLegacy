import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../theme/adaptive_field_theme.dart';

/// Shows the "Calculating stats..." blocking dialog. Caller is responsible
/// for calling Navigator.pop(context) once calculation is complete.
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

Future<void> showExportResultDialog(BuildContext context, {required String text}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Team'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Semantics(
            label: 'Team export text',
            child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Copy exported team text to clipboard',
          child: FilledButton(
            style: AdaptiveFieldTheme.filledButtonStyle(context),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
            child: const Text('Copy'),
          ),
        ),
        Semantics(
          button: true,
          label: 'Close export dialog',
          child: TextButton(
            style: AdaptiveFieldTheme.textButtonStyle(context),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    ),
  );
}