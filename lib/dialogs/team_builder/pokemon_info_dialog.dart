import 'package:flutter/material.dart';
import '../../models/pokemon_details.dart';
import '../../theme/adaptive_field_theme.dart';

Future<void> showPokemonInfoDialog(
  BuildContext context,
  PokemonDetails details, {
  PokemonDetails? megaDetails,
  String? megaFormName,
}) {
  String genderRateLabel(int rate) {
    if (rate == -1) return 'Genderless';
    if (rate == 0) return 'Always Male';
    if (rate == 8) return 'Always Female';
    final femalePercent = (rate / 8 * 100).round();
    return '$femalePercent% Female / ${100 - femalePercent}% Male';
  }

  Widget buildSection(PokemonDetails d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Types: ${d.types.map((t) => t.toUpperCase()).join(' / ')}'),
        const SizedBox(height: 4),
        Text(
            'Height: ${d.heightMeters.toStringAsFixed(1)} m   Weight: ${d.weightKilograms.toStringAsFixed(1)} kg'),
        const SizedBox(height: 8),
        const Text('Base Stats', style: TextStyle(fontWeight: FontWeight.bold)),
        ...d.baseStats.entries.map((e) => Text('${e.key}: ${e.value}')),
        const SizedBox(height: 8),
        const Text('Abilities', style: TextStyle(fontWeight: FontWeight.bold)),
        ...d.abilities
            .map((a) => Text('${a['name']}${a['isHidden'] == true ? ' (Hidden)' : ''}')),
      ],
    );
  }

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
              Text('Gender Rate: ${genderRateLabel(details.genderRate)}'),
              const SizedBox(height: 8),
              buildSection(details),
              if (megaDetails != null) ...[
                const SizedBox(height: 16),
                Text('Mega Evolution: ${megaFormName ?? megaDetails.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                buildSection(megaDetails),
              ],
              const SizedBox(height: 12),
              Text('Move Learn Set (${details.moveLearnSet.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                details.moveLearnSet.isEmpty ? 'No moves found.' : details.moveLearnSet.join(', '),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Close info dialog for ${details.name}',
          child: ExcludeSemantics(
            child: FilledButton(
              style: AdaptiveFieldTheme.filledButtonStyle(context),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ),
      ],
    ),
  );
}