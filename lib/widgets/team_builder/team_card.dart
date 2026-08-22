import 'package:flutter/material.dart';
import '../../models/team_member.dart';
import '../../theme/adaptive_field_theme.dart';
import 'details_panel.dart';
import 'evs_panel.dart';
import 'moves_panel.dart';

/// Renders one team member's card: compact header (always visible),
/// expanded summary, toolbar toggles, and whichever sub-panel is active.
///
/// This widget is intentionally "dumb" — all state (which panel is open,
/// controllers, caches) lives in the parent screen and is passed in.
class TeamCard extends StatelessWidget {
  final TeamMember member;
  final int index;
  final bool isCollapsed;
  final String? activePanel;

  final List<String>? moveOptions;
  final List<Map<String, dynamic>>? abilityOptions;
  final List<String> cachedValidItems;
  final Map<String, TextEditingController>? evControllers;
  final Map<String, FocusNode>? evFocusNodes;
  final TextEditingController? itemController;
  final FocusNode? itemFocus;

  final VoidCallback onToggleCollapsed;
  final VoidCallback onRemove;
  final void Function(String panelName) onTogglePanel;
  final VoidCallback onShowStats;
  final VoidCallback onShowInfo;

  final void Function(int slot, String? move) onSetMove;
  final void Function(String gender) onSetGender;
  final void Function(String ability) onSetAbility;
  final void Function(String nature) onSetNature;
  final void Function(String stat) onCommitEv;
  final VoidCallback onCommitHeldItem;
  final Future<void> Function(String selection) onSelectHeldItem;
  final Future<void> Function() onClearHeldItem;

  const TeamCard({
    super.key,
    required this.member,
    required this.index,
    required this.isCollapsed,
    required this.activePanel,
    required this.moveOptions,
    required this.abilityOptions,
    required this.cachedValidItems,
    required this.evControllers,
    required this.evFocusNodes,
    required this.itemController,
    required this.itemFocus,
    required this.onToggleCollapsed,
    required this.onRemove,
    required this.onTogglePanel,
    required this.onShowStats,
    required this.onShowInfo,
    required this.onSetMove,
    required this.onSetGender,
    required this.onSetAbility,
    required this.onSetNature,
    required this.onCommitEv,
    required this.onCommitHeldItem,
    required this.onSelectHeldItem,
    required this.onClearHeldItem,
  });

  @override
  Widget build(BuildContext context) {
    final nonNullMoves = member.moves.where((m) => m != null && m.isNotEmpty).join(', ');
    final movesDisplay = nonNullMoves.isEmpty ? 'None set' : nonNullMoves;

    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                '${member.name}. Item: ${member.heldItem ?? "none"}. Gender: ${member.gender}. Ability: ${member.ability ?? "none"}. Nature: ${member.nature}. EVs: ${member.evTotal} of 510. Moves: $movesDisplay.',
            child: InkWell(
              onTap: onToggleCollapsed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${member.name.toUpperCase()}  #${member.pokedexNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: isCollapsed
                          ? 'Expand ${member.name} details'
                          : 'Collapse ${member.name} details',
                      child: IconButton(
                        icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: onToggleCollapsed,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Remove ${member.name} from team',
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: onRemove,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text('Item: ${member.heldItem ?? "None"}', style: const TextStyle(fontSize: 12)),
                  Text('Gender: ${member.gender}', style: const TextStyle(fontSize: 12)),
                  Text('Ability: ${member.ability ?? "None"}', style: const TextStyle(fontSize: 12)),
                  Text('Nature: ${member.nature}', style: const TextStyle(fontSize: 12)),
                  Text('EVs: ${member.evTotal}/510', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text(
                'Moves: $movesDisplay',
                style: TextStyle(fontSize: 12, color: secondaryTextColor, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Container(
              color: AdaptiveFieldTheme.containerColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ToolbarToggle(
                    label: 'Details',
                    isActive: activePanel == 'details',
                    semanticLabel: activePanel == 'details'
                        ? 'Collapse held item, gender, ability, and nature editor for ${member.name}'
                        : 'Expand held item, gender, ability, and nature editor for ${member.name}',
                    onPressed: () => onTogglePanel('details'),
                  ),
                  _ToolbarToggle(
                    label: 'Moves',
                    isActive: activePanel == 'moves',
                    semanticLabel: activePanel == 'moves'
                        ? 'Collapse moveset editor for ${member.name}'
                        : 'Expand moveset editor for ${member.name}',
                    onPressed: () => onTogglePanel('moves'),
                  ),
                  _ToolbarToggle(
                    label: 'EVs',
                    isActive: activePanel == 'evs',
                    semanticLabel: activePanel == 'evs'
                        ? 'Collapse effort value editor for ${member.name}'
                        : 'Expand effort value editor for ${member.name}',
                    onPressed: () => onTogglePanel('evs'),
                  ),
                  _ToolbarToggle(
                    label: 'Stats',
                    isActive: false,
                    semanticLabel: 'Show calculated stats for ${member.name}',
                    onPressed: onShowStats,
                  ),
                  _ToolbarToggle(
                    label: 'Info',
                    isActive: false,
                    semanticLabel:
                        'Show species info for ${member.name}: types, height, weight, abilities, and move learn set',
                    onPressed: onShowInfo,
                  ),
                ],
              ),
            ),
            if (activePanel != null) ...[
              Divider(height: 1, color: theme.dividerColor),
              Container(
                color: AdaptiveFieldTheme.containerColor(context),
                width: double.infinity,
                padding: const EdgeInsets.all(10.0),
                child: DefaultTextStyle(
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  child: _buildPanelContent(context),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPanelContent(BuildContext context) {
    switch (activePanel) {
      case 'moves':
        return MovesPanel(
          member: member,
          moveOptions: moveOptions,
          onSetMove: onSetMove,
        );
      case 'details':
        if (itemController == null || itemFocus == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return DetailsPanel(
          member: member,
          abilityOptions: abilityOptions,
          cachedValidItems: cachedValidItems,
          itemController: itemController!,
          itemFocus: itemFocus!,
          onSetGender: onSetGender,
          onSetAbility: onSetAbility,
          onSetNature: onSetNature,
          onCommitHeldItem: onCommitHeldItem,
          onSelectHeldItem: onSelectHeldItem,
          onClearHeldItem: onClearHeldItem,
        );
      case 'evs':
        if (evControllers == null || evFocusNodes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return EvsPanel(
          member: member,
          controllers: evControllers!,
          focusNodes: evFocusNodes!,
          onCommit: onCommitEv,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ToolbarToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final String? semanticLabel;

  const _ToolbarToggle({
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg = isActive ? Colors.grey.withValues(alpha: 0.35) : Colors.transparent;
    final Color textColor = isActive ? cs.onSurface : cs.onSurface.withValues(alpha: 0.70);
    final FontWeight weight = isActive ? FontWeight.bold : FontWeight.normal;

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      selected: isActive,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: textColor, fontWeight: weight),
            ),
          ),
        ),
      ),
    );
  }
}