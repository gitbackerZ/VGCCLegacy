import 'package:flutter/material.dart';
import '../../services/team_file_storage.dart';
import '../../theme/adaptive_field_theme.dart';

Future<String?> showImportPasteDialog(BuildContext context, TeamFileStorage storage) async {
  final controller = TextEditingController();
  List<SavedTeamFile> savedFiles = await storage.listSavedTeams();

  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> refresh() async {
          final files = await storage.listSavedTeams();
          setDialogState(() => savedFiles = files);
        }

        return AlertDialog(
          title: const Text('Import Team'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (savedFiles.isNotEmpty) ...[
                    const Text('Saved Teams',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: savedFiles.length,
                        itemBuilder: (context, i) {
                          final f = savedFiles[i];
                          return Semantics(
                            button: true,
                            label: 'Load saved team ${f.name}',
                            child: ExcludeSemantics(
                              child: ListTile(
                                dense: true,
                                title: Text(f.name),
                                subtitle: Text(
                                  '${f.modified.year}-${f.modified.month.toString().padLeft(2, '0')}-${f.modified.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Semantics(
                                  button: true,
                                  label: 'Delete saved team ${f.name}',
                                  child: ExcludeSemantics(
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () async {
                                        await storage.deleteTeam(f.file);
                                        await refresh();
                                      },
                                    ),
                                  ),
                                ),
                                onTap: () async {
                                  final text = await storage.readTeam(f.file);
                                  if (context.mounted) Navigator.pop(context, text);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 20),
                  ],
                  const Text('Or Paste Team Text',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Semantics(
                    label: 'Paste team text here',
                    textField: true,
                    child: TextField(
                      controller: controller,
                      maxLines: 8,
                      style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context)),
                      cursorColor: AdaptiveFieldTheme.cursorColor(context),
                      decoration: AdaptiveFieldTheme.inputDecoration(context, '').copyWith(
                        hintText: 'Paste exported team text here',
                        hintStyle: TextStyle(color: AdaptiveFieldTheme.hintTextColor(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Cancel import',
              child: ExcludeSemantics(
                child: TextButton(
                  style: AdaptiveFieldTheme.textButtonStyle(context),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Parse pasted team text',
              child: ExcludeSemantics(
                child: FilledButton(
                  style: AdaptiveFieldTheme.filledButtonStyle(context),
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Parse'),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

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
          child: ExcludeSemantics(
            child: TextButton(
              style: AdaptiveFieldTheme.textButtonStyle(context),
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Add $parsedCount imported Pokémon to current team',
          child: ExcludeSemantics(
            child: FilledButton(
              style: AdaptiveFieldTheme.filledButtonStyle(context),
              onPressed: () => Navigator.pop(context, 'add'),
              child: const Text('Add to Team'),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Replace current team with $parsedCount imported Pokémon',
          child: ExcludeSemantics(
            child: FilledButton(
              style: AdaptiveFieldTheme.filledButtonStyle(context),
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text('Replace Team'),
            ),
          ),
        ),
      ],
    ),
  );
}