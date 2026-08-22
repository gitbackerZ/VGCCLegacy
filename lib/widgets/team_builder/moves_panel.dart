import 'package:flutter/material.dart';
import '../../models/team_member.dart';
import '../../theme/adaptive_field_theme.dart';

class MovesPanel extends StatelessWidget {
  final TeamMember member;
  final List<String>? moveOptions;
  final void Function(int slot, String? move) onSetMove;

  const MovesPanel({
    super.key,
    required this.member,
    required this.moveOptions,
    required this.onSetMove,
  });

  @override
  Widget build(BuildContext context) {
    final options = moveOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configure Moveset',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        if (options == null)
          const Center(child: CircularProgressIndicator())
        else
          // 2 columns × 2 rows → at most 2 visual rows of fields
          ...List.generate(2, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (int col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Builder(builder: (_) {
                        final slot = row * 2 + col;
                        return Semantics(
                          label: 'Move slot ${slot + 1} for ${member.name}',
                          child: DropdownButtonFormField<String>(
                            initialValue: member.moves[slot],
                            isExpanded: true,
                            dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
                            style: TextStyle(
                                color: AdaptiveFieldTheme.fieldTextColor(context),
                                fontSize: 14),
                            decoration: AdaptiveFieldTheme.inputDecoration(
                                context, 'Move ${slot + 1}'),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text('None',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.70))),
                              ),
                              ...options.map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m,
                                        style: TextStyle(
                                            color: AdaptiveFieldTheme
                                                .fieldTextColor(context))),
                                  )),
                            ],
                            onChanged: (value) => onSetMove(slot, value),
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