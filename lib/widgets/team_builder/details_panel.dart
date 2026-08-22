import 'package:flutter/material.dart';
import '../../data/natures.dart';
import '../../models/team_member.dart';
import '../../theme/adaptive_field_theme.dart';

class DetailsPanel extends StatelessWidget {
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

  const DetailsPanel({
    super.key,
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
      genderItems = [
        DropdownMenuItem(value: 'Genderless', child: Text('Genderless', style: itemStyle)),
      ];
    } else if (member.genderRate == 0) {
      genderItems = [
        DropdownMenuItem(value: 'Male', child: Text('Male', style: itemStyle)),
      ];
    } else if (member.genderRate == 8) {
      genderItems = [
        DropdownMenuItem(value: 'Female', child: Text('Female', style: itemStyle)),
      ];
    } else {
      genderItems = [
        DropdownMenuItem(value: 'Male', child: Text('Male', style: itemStyle)),
        DropdownMenuItem(value: 'Female', child: Text('Female', style: itemStyle)),
      ];
    }

    Widget abilityField;
    final options = abilityOptions;
    if (options == null) {
      abilityField = const Center(child: CircularProgressIndicator());
    } else {
      abilityField = Semantics(
        label: 'Ability for ${member.name}, currently ${member.ability ?? "none"}',
        child: DropdownButtonFormField<String>(
          initialValue: member.ability,
          isExpanded: true,
          dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
          style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context), fontSize: 14),
          decoration: AdaptiveFieldTheme.inputDecoration(context, 'Ability'),
          items: options.map((a) {
            final label = a['isHidden'] ? '${a['name']} (Hidden)' : a['name'];
            return DropdownMenuItem<String>(
              value: a['name'] as String,
              child: Text(label, style: itemStyle),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onSetAbility(value);
          },
        ),
      );
    }

    final genderField = Semantics(
      label: 'Gender for ${member.name}, currently ${member.gender}',
      child: DropdownButtonFormField<String>(
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
      ),
    );

    final natureField = Semantics(
      label: 'Nature for ${member.name}, currently ${member.nature}',
      child: DropdownButtonFormField<String>(
        initialValue: member.nature,
        isExpanded: true,
        dropdownColor: AdaptiveFieldTheme.dropdownMenuColor(context),
        style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context), fontSize: 14),
        decoration: AdaptiveFieldTheme.inputDecoration(context, 'Nature'),
        items: allNatures.map((n) {
          final desc = n.boosted == null
              ? '${n.name} (neutral)'
              : '${n.name} (+${n.boosted}, -${n.lowered})';
          return DropdownMenuItem(value: n.name, child: Text(desc, style: itemStyle));
        }).toList(),
        onChanged: (value) {
          if (value != null) onSetNature(value);
        },
      ),
    );

    final itemField = Semantics(
      label:
          'Held item for ${member.name}, currently ${member.heldItem ?? "none"}. Type to search.',
      textField: true,
      child: RawAutocomplete<String>(
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
                      child: IconButton(
                        onPressed: () async {
                          textController.clear();
                          await onClearHeldItem();
                        },
                        icon: Icon(Icons.clear, color: AdaptiveFieldTheme.iconColor(context)),
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
          final soft = AdaptiveFieldTheme.optionsListColor(context);
          final cs = Theme.of(context).colorScheme;
          return Align(
            alignment: Alignment.bottomLeft,
            child: Material(
              elevation: 6,
              color: soft,
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
                      child: ListTile(
                        dense: true,
                        title: Text(option,
                            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.92))),
                        onTap: () => onSelected(option),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
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
            children: [
              Expanded(child: itemField),
              const SizedBox(width: 8),
              Expanded(child: genderField),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: abilityField),
              const SizedBox(width: 8),
              Expanded(child: natureField),
            ],
          ),
        ),
      ],
    );
  }
}