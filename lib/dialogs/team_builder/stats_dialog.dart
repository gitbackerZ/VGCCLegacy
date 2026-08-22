import 'package:flutter/material.dart';
import '../../data/natures.dart';
import '../../theme/adaptive_field_theme.dart';

/// Pure presentation dialog: the screen computes normal/mega stats up front
/// (it owns the PokeApiService + StatCalculator calls) and passes the
/// results in here.
Future<void> showStatsDialog(
  BuildContext context, {
  required String memberName,
  required String gender,
  required String natureName,
  required Map<String, int> normalStats,
  Map<String, int>? megaStats,
  String? megaFormName,
  String? megaAbility,
}) {
  final nature = allNatures.firstWhere((n) => n.name == natureName);

  List<Widget> buildStatRows(Map<String, int> stats) {
    return stats.entries.map((e) {
      final isBoosted = (e.key == 'Atk' && nature.boosted == 'Attack') ||
          (e.key == 'Def' && nature.boosted == 'Defense') ||
          (e.key == 'SpA' && nature.boosted == 'Sp. Atk') ||
          (e.key == 'SpD' && nature.boosted == 'Sp. Def') ||
          (e.key == 'Spe' && nature.boosted == 'Speed');
      final isLowered = (e.key == 'Atk' && nature.lowered == 'Attack') ||
          (e.key == 'Def' && nature.lowered == 'Defense') ||
          (e.key == 'SpA' && nature.lowered == 'Sp. Atk') ||
          (e.key == 'SpD' && nature.lowered == 'Sp. Def') ||
          (e.key == 'Spe' && nature.lowered == 'Speed');
      final suffix = isBoosted ? ' (+)' : (isLowered ? ' (-)' : '');
      return Semantics(
        label: '${e.key}: ${e.value}${isBoosted ? ", boosted" : ""}${isLowered ? ", lowered" : ""}',
        child: Text('${e.key}: ${e.value}$suffix'),
      );
    }).toList();
  }

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${memberName.toUpperCase()} — Level 50 Stats'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gender: $gender • Nature: $natureName'),
            const SizedBox(height: 8),
            const Text('Assumes max IVs (31) at Level 50.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            const Text('Base Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...buildStatRows(normalStats),
            if (megaStats != null) ...[
              const SizedBox(height: 16),
              Text('Mega Evolution: $megaFormName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (megaAbility != null)
                Text('Ability: $megaAbility', style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 4),
              ...buildStatRows(megaStats),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'No Mega Evolution active. Hold the correct Mega Stone to Mega Evolve.',
                style: TextStyle(color: Colors.orange, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Close stats dialog for $memberName',
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