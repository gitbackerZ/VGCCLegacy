import 'package:flutter/material.dart';
import '../../models/pokemon_details.dart';
import '../../theme/adaptive_field_theme.dart';

Future<void> showPokemonInfoDialog(BuildContext context, PokemonDetails details) {
  String genderRateLabel(int rate) {
    if (rate == -1) return 'Genderless';
    if (rate == 0) return 'Always Male';
    if (rate == 8) return 'Always Female';
    final femalePercent = (rate / 8 * 100).round();
    return '$femalePercent% Female / ${100 - femalePercent}% Male';
  }

  final movesByMethod = <String, List<LearnableMove>>{};
  for (final m in details.moveLearnSet) {
    movesByMethod.putIfAbsent(m.learnMethod, () => []).add(m);
  }
  movesByMethod['level-up']
      ?.sort((a, b) => (a.levelLearnedAt ?? 0).compareTo(b.levelLearnedAt ?? 0));

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(details.name.toUpperCase()),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Types: ${details.types.map((t) => t.toUpperCase()).join(' / ')}'),
              const SizedBox(height: 4),
              Text('Gender Rate: ${genderRateLabel(details.genderRate)}'),
              const SizedBox(height: 4),
              Text(
                  'Height: ${details.heightMeters.toStringAsFixed(1)} m   Weight: ${details.weightKilograms.toStringAsFixed(1)} kg'),
              const SizedBox(height: 12),
              const Text('Base Stats', style: TextStyle(fontWeight: FontWeight.bold)),
              ...details.baseStats.entries.map((e) => Text('${e.key}: ${e.value}')),
              const SizedBox(height: 12),
              const Text('Abilities', style: TextStyle(fontWeight: FontWeight.bold)),
              ...details.abilities.map(
                  (a) => Text('${a['name']}${a['isHidden'] == true ? ' (Hidden)' : ''}')),
              const SizedBox(height: 12),
              Text('Move Learn Set (${details.moveLearnSet.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (details.moveLearnSet.isEmpty)
                const Text(
                  'No moves found for the current ruleset.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                )
              else
                for (final method in movesByMethod.keys) ...[
                  Text(method.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(
                    movesByMethod[method]!
                        .map((m) => m.levelLearnedAt != null
                            ? '${m.name} (Lv ${m.levelLearnedAt})'
                            : m.name)
                        .join(', '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Close info dialog for ${details.name}',
          child: FilledButton(
            style: AdaptiveFieldTheme.filledButtonStyle(context),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    ),
  );
}