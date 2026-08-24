import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import '../../data/natures.dart';
import '../../models/team_member.dart';
import '../../models/pokemon_details.dart';
import '../../theme/adaptive_field_theme.dart';

class TeamCard extends StatelessWidget {
  final TeamMember member;
  final int index;
  final bool isCollapsed;
  final String? activePanel;
  final PokemonDetails? details;
  final bool isMegaActive;

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
  final VoidCallback onToggleMega;

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
    required this.details,
    required this.isMegaActive,
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
    required this.onToggleMega,
    required this.onSetMove,
    required this.onSetGender,
    required this.onSetAbility,
    required this.onSetNature,
    required this.onCommitEv,
    required this.onCommitHeldItem,
    required this.onSelectHeldItem,
    required this.onClearHeldItem,
  });

  /// The ability shown in the header — the Mega form's ability when Mega is
  /// active and resolved, otherwise the member's configured ability.
  String? get _displayedAbility {
    if (isMegaActive && details != null && details!.abilities.isNotEmpty) {
      return details!.abilities.first['name'] as String;
    }
    return member.ability;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          if (!isCollapsed) _buildBody(context),
          _buildToolbar(context),
          if (activePanel != null) _buildPanelContent(context),
        ],
      ),
    );
  }

  // ---- Header (red) — always visible ----
  Widget _buildHeader(BuildContext context) {
    final types = details?.types ?? const <String>[];
    final typesText = types.isEmpty ? '—' : types.map((t) => t.toUpperCase()).join(' / ');
    final abilityText = _displayedAbility ?? '—';
    final itemText = member.heldItem ?? '—';

    return Container(
      color: AdaptiveFieldTheme.pokeballRed,
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label:
                      '${member.name}, dex number ${member.pokedexNumber}${isMegaActive ? ", Mega evolved" : ""}',
                  child: ExcludeSemantics(
                    child: Text(
                      member.name.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: AdaptiveFieldTheme.headerText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: isMegaActive
                    ? 'Revert ${member.name} from Mega Evolution'
                    : 'Mega Evolve ${member.name}',
                selected: isMegaActive,
                child: ExcludeSemantics(
                  child: IconButton(
                    icon: Icon(Icons.auto_awesome,
                        size: 20, color: isMegaActive ? Colors.amberAccent : Colors.white70),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onToggleMega,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: isCollapsed ? 'Expand ${member.name} details' : 'Collapse ${member.name} details',
                child: ExcludeSemantics(
                  child: IconButton(
                    icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 22, color: AdaptiveFieldTheme.headerText),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onToggleCollapsed,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Remove ${member.name} from team',
                child: ExcludeSemantics(
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onRemove,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Row 1 (large): Pokémon name repeated is redundant with the title
          // above, so this row instead pairs Types opposite the name slot —
          // Types large, matching the name's visual weight.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: 'Types: $typesText',
                  child: ExcludeSemantics(
                    child: Text(
                      typesText,
                      style: const TextStyle(
                          color: AdaptiveFieldTheme.headerText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2 (small): Held Item | Ability
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Held item: $itemText',
                  child: ExcludeSemantics(
                    child: Text(itemText,
                        style: const TextStyle(color: AdaptiveFieldTheme.headerText, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Ability: $abilityText',
                  child: ExcludeSemantics(
                    child: Text(abilityText,
                        style: const TextStyle(color: AdaptiveFieldTheme.headerText, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Body (dark gray) — collapsible; rest of the Pokémon's info ----
  Widget _buildBody(BuildContext context) {
    final nonzeroEvs = member.evs.entries.where((e) => e.value > 0);
    final evsText = nonzeroEvs.isEmpty
        ? '—'
        : nonzeroEvs.map((e) => '${e.value} ${e.key}').join(', ');
    final moves = member.moves.where((m) => m != null && m.isNotEmpty).join(', ');
    final movesText = moves.isEmpty ? '—' : moves;
    final heightText = details != null ? '${details!.heightMeters.toStringAsFixed(1)} m' : '—';
    final weightText = details != null ? '${details!.weightKilograms.toStringAsFixed(1)} kg' : '—';

    return Container(
      color: AdaptiveFieldTheme.pokeballDarkGray,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Gender: ${member.gender}',
                  child: ExcludeSemantics(
                    child: Text(member.gender,
                        style: const TextStyle(color: AdaptiveFieldTheme.bodyText, fontSize: 13)),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Nature: ${member.nature}',
                  child: ExcludeSemantics(
                    child: Text(member.nature,
                        style: const TextStyle(color: AdaptiveFieldTheme.bodyText, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Height: $heightText',
                  child: ExcludeSemantics(
                    child: Text(heightText,
                        style: const TextStyle(color: AdaptiveFieldTheme.bodyText, fontSize: 13)),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Weight: $weightText',
                  child: ExcludeSemantics(
                    child: Text(weightText,
                        style: const TextStyle(color: AdaptiveFieldTheme.bodyText, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Effort values: $evsText',
            child: ExcludeSemantics(
              child: Text(evsText,
                  style: const TextStyle(color: AdaptiveFieldTheme.bodyText, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 2),
          Semantics(
            label: 'Moveset: $movesText',
            child: ExcludeSemantics(
              child: Text(movesText,
                  style: const TextStyle(color: AdaptiveFieldTheme.bodyText, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Toolbar (white) — permanent, always visible ----
  Widget _buildToolbar(BuildContext context) {
    return Container(
      color: AdaptiveFieldTheme.toolbarBg,
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
            semanticLabel: 'Show species info for ${member.name}',
            onPressed: onShowInfo,
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(BuildContext context) {
    return Container(
      color: AdaptiveFieldTheme.containerColor(context),
      width: double.infinity,
      padding: const EdgeInsets.all(10.0),
      child: DefaultTextStyle(
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        child: switch (activePanel) {
          'moves' => _MovesEditor(member: member, moveOptions: moveOptions, onSetMove: onSetMove),
          'details' => (itemController == null || itemFocus == null)
              ? const Center(child: CircularProgressIndicator())
              : _DetailsEditor(
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
                ),
          'evs' => (evControllers == null || evFocusNodes == null)
              ? const Center(child: CircularProgressIndicator())
              : _EvsEditor(
                  member: member,
                  controllers: evControllers!,
                  focusNodes: evFocusNodes!,
                  onCommit: onCommitEv,
                ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
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
    final Color bg = isActive ? Colors.grey.withValues(alpha: 0.25) : Colors.transparent;
    final FontWeight weight = isActive ? FontWeight.bold : FontWeight.normal;

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      selected: isActive,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: AdaptiveFieldTheme.toolbarText, fontWeight: weight),
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Merged editor panels ============

class _MovesEditor extends StatelessWidget {
  final TeamMember member;
  final List<String>? moveOptions;
  final void Function(int slot, String? move) onSetMove;

  const _MovesEditor({required this.member, required this.moveOptions, required this.onSetMove});

  @override
  Widget build(BuildContext context) {
    final options = moveOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Configure Moveset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        if (options == null)
          const Center(child: CircularProgressIndicator())
        else
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
                        // DropdownButtonFormField provides its own accessible
                        // semantics (field label + current value + "button"
                        // role) — do not wrap it in ExcludeSemantics or
                        // TalkBack/VoiceOver will skip it entirely. The
                        // labelText below already carries the slot number,
                        // which is enough context for screen readers.
                        return DropdownButtonFormField<String>(
                          initialValue: member.moves[slot],
                          isExpanded: true,
                          dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
                          style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context), fontSize: 14),
                          decoration: AdaptiveFieldTheme.inputDecoration(context, 'Move ${slot + 1}'),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('None',
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70))),
                            ),
                            ...options.map((m) => DropdownMenuItem(
                                  value: m,
                                  child:
                                      Text(m, style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context))),
                                )),
                          ],
                          onChanged: (value) => onSetMove(slot, value),
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

class _EvsEditor extends StatelessWidget {
  final TeamMember member;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final void Function(String stat) onCommit;

  const _EvsEditor({
    required this.member,
    required this.controllers,
    required this.focusNodes,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    final stats = member.evs.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Effort Values (EVs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                      if (statIndex >= stats.length) return const SizedBox.shrink();
                      final stat = stats[statIndex];
                      // TextField carries its own semantics (edit text +
                      // current value); the floating labelText below ("HP",
                      // "Atk", etc.) is what makes the stat name announced —
                      // do not exclude/replace this widget's semantics.
                      return TextField(
                        controller: controllers[stat],
                        focusNode: focusNodes[stat],
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context)),
                        cursorColor: AdaptiveFieldTheme.cursorColor(context),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: AdaptiveFieldTheme.inputDecoration(
                          context,
                          stat,
                          alwaysFloatLabel: true,
                        ),
                        onEditingComplete: () {
                          onCommit(stat);
                          focusNodes[stat]?.unfocus();
                        },
                        onSubmitted: (_) => onCommit(stat),
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

class _DetailsEditor extends StatelessWidget {
  final TeamMember member;
  final List<Map<String, dynamic>>? abilityOptions;
  final List<String> cachedValidItems;
  final TextEditingController itemController;
  final FocusNode itemFocus;
  final void Function(String gender) onSetGender;
  final void Function(String ability) onSetAbility;
  final void Function(String nature) onSetNature;
  final void Function() onCommitHeldItem;
  final Future<void> Function(String selection) onSelectHeldItem;
  final Future<void> Function() onClearHeldItem;

  const _DetailsEditor({
    required this.member,
    required this.abilityOptions,
    required this.cachedValidItems,
    required this.itemController,
    required this.itemFocus,
    required this.onSetGender,
    required this.onSetAbility,
    required this.onSetNature,
    required this.onCommitHeldItem,
    required this.onSelectHeldItem,
    required this.onClearHeldItem,
  });

  @override
  Widget build(BuildContext context) {
    final itemStyle = TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context));

    List<DropdownMenuItem<String>> genderItems;
    if (member.genderRate == -1) {
      genderItems = [DropdownMenuItem(value: 'Genderless', child: Text('Genderless', style: itemStyle))];
    } else if (member.genderRate == 0) {
      genderItems = [DropdownMenuItem(value: 'Male', child: Text('Male', style: itemStyle))];
    } else if (member.genderRate == 8) {
      genderItems = [DropdownMenuItem(value: 'Female', child: Text('Female', style: itemStyle))];
    } else {
      genderItems = [
        DropdownMenuItem(value: 'Male', child: Text('Male', style: itemStyle)),
        DropdownMenuItem(value: 'Female', child: Text('Female', style: itemStyle)),
      ];
    }

    // All DropdownButtonFormField / TextField / RawAutocomplete instances
    // below are left with their native semantics intact (no ExcludeSemantics
    // wrapper) — they are real form controls, and hiding them breaks
    // TalkBack/VoiceOver navigation entirely rather than just de-duplicating
    // labels. Their labelText (Ability/Gender/Nature/Held Item) already
    // gives screen readers what they need.

    Widget abilityField;
    final options = abilityOptions;
    if (options == null) {
      abilityField = const Center(child: CircularProgressIndicator());
    } else {
      abilityField = DropdownButtonFormField<String>(
        initialValue: member.ability,
        isExpanded: true,
        dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
        style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context), fontSize: 14),
        decoration: AdaptiveFieldTheme.inputDecoration(context, 'Ability'),
        items: options.map((a) {
          final label = a['isHidden'] ? '${a['name']} (Hidden)' : a['name'];
          return DropdownMenuItem<String>(value: a['name'] as String, child: Text(label, style: itemStyle));
        }).toList(),
        onChanged: (value) {
          if (value != null) onSetAbility(value);
        },
      );
    }

    final genderField = DropdownButtonFormField<String>(
      initialValue: member.gender,
      isExpanded: true,
      dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
      style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context), fontSize: 14),
      decoration: AdaptiveFieldTheme.inputDecoration(context, 'Gender'),
      items: genderItems,
      onChanged: genderItems.length > 1
          ? (value) {
              if (value != null) onSetGender(value);
            }
          : null,
    );

    final natureField = DropdownButtonFormField<String>(
      initialValue: member.nature,
      isExpanded: true,
      dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
      style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context), fontSize: 14),
      decoration: AdaptiveFieldTheme.inputDecoration(context, 'Nature'),
      items: allNatures.map((n) {
        final desc =
            n.boosted == null ? '${n.name} (neutral)' : '${n.name} (+${n.boosted}, -${n.lowered})';
        return DropdownMenuItem(value: n.name, child: Text(desc, style: itemStyle));
      }).toList(),
      onChanged: (value) {
        if (value != null) onSetNature(value);
      },
    );

    final itemField = RawAutocomplete<String>(
      textEditingController: itemController,
      focusNode: itemFocus,
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return cachedValidItems.where((item) => item.toLowerCase().contains(q)).take(20);
      },
      onSelected: (String selection) async {
        itemController.text = selection;
        await onSelectHeldItem(selection);
        itemFocus.unfocus();
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context)),
          cursorColor: AdaptiveFieldTheme.cursorColor(context),
          decoration: AdaptiveFieldTheme.inputDecoration(context, 'Held Item').copyWith(
            hintText: 'Type to search items…',
            hintStyle: TextStyle(color: AdaptiveFieldTheme.hintTextColor(context)),
            suffixIcon: textController.text.isNotEmpty
                ? Semantics(
                    button: true,
                    label: 'Clear held item for ${member.name}',
                    child: ExcludeSemantics(
                      child: IconButton(
                        onPressed: () async {
                          textController.clear();
                          await onClearHeldItem();
                        },
                        icon: Icon(Icons.clear, color: AdaptiveFieldTheme.iconColor(context)),
                      ),
                    ),
                  )
                : Icon(Icons.search, color: AdaptiveFieldTheme.iconColor(context)),
          ),
          onEditingComplete: () {
            onCommitHeldItem();
            focusNode.unfocus();
          },
          onSubmitted: (_) {
            onCommitHeldItem();
            onFieldSubmitted();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final cs = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.bottomLeft,
          child: Material(
            elevation: 6,
            color: AdaptiveFieldTheme.optionsListColor(context),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return Semantics(
                    button: true,
                    label: 'Set held item to $option',
                    child: ExcludeSemantics(
                      child: ListTile(
                        dense: true,
                        title: Text(option, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.92))),
                        onTap: () => onSelected(option),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Held Item, Gender, Ability & Nature',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: itemField), const SizedBox(width: 8), Expanded(child: genderField)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: abilityField), const SizedBox(width: 8), Expanded(child: natureField)],
          ),
        ),
      ],
    );
  }
}