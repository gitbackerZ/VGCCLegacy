import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../../models/team_member.dart';
import '../../theme/adaptive_field_theme.dart';

class EvsPanel extends StatelessWidget {
  final TeamMember member;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final void Function(String stat) onCommit;

  const EvsPanel({
    super.key,
    required this.member,
    required this.controllers,
    required this.focusNodes,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    final stats = member.evs.keys.toList(); // HP Atk Def SpA SpD Spe

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Effort Values (EVs)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Semantics(
              liveRegion: true,
              child: Text(
                '${member.evTotal}/510 total',
                style: TextStyle(
                  fontSize: 13,
                  color: member.evTotal > 510
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 2 columns × 3 rows → at most 3 visual rows of fields
        ...List.generate(3, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (int col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Builder(builder: (_) {
                      final statIndex = row * 2 + col;
                      if (statIndex >= stats.length) {
                        return const SizedBox.shrink();
                      }
                      final stat = stats[statIndex];
                      return Semantics(
                        label:
                            '$stat effort values, currently ${member.evs[stat]} out of 252',
                        textField: true,
                        child: TextField(
                          controller: controllers[stat],
                          focusNode: focusNodes[stat],
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: AdaptiveFieldTheme.fieldTextColor(context)),
                          cursorColor: AdaptiveFieldTheme.cursorColor(context),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: AdaptiveFieldTheme.inputDecoration(
                              context, '$stat EVs (0-252)'),
                          onEditingComplete: () {
                            onCommit(stat);
                            focusNodes[stat]?.unfocus();
                          },
                          onSubmitted: (_) => onCommit(stat),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}