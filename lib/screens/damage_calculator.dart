import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../services/pokeapi_service.dart';

class DamageCalculatorScreen extends StatefulWidget {
  const DamageCalculatorScreen({super.key});

  @override
  State<DamageCalculatorScreen> createState() => _DamageCalculatorScreenState();
}

class _DamageCalculatorScreenState extends State<DamageCalculatorScreen> {
  final _attackerController = TextEditingController();
  final _defenderController = TextEditingController();
  final _moveController = TextEditingController();
  final _service = PokeApiService();

  String _result = '';
  bool _loading = false;

  Future<void> _calculate() async {
    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      final attacker = await _service.getPokemon(_attackerController.text.trim());
      final defender = await _service.getPokemon(_defenderController.text.trim());
      final move = await _service.getMove(_moveController.text.trim());

      final power = move['power'] ?? 0;
      final attackStat = _getStat(attacker, 'attack');
      final defenseStat = _getStat(defender, 'defense');

      // Simplified damage formula (Level 50, no modifiers)
      final damage = (((2 * 50 / 5 + 2) * power * attackStat / defenseStat) / 50 + 2).round();
      final maxHp = _getStat(defender, 'hp');
      final percent = ((damage / maxHp) * 100).clamp(0, 100).toStringAsFixed(1);

      setState(() {
        _result =
            '${_attackerController.text}\'s ${_moveController.text} deals approximately $damage damage, or $percent percent of ${_defenderController.text}\'s HP.';
        _loading = false;
      });

      SemanticsService.announce(_result, TextDirection.ltr);
    } catch (e) {
      setState(() {
        _result = 'Error: could not calculate. Check spelling and try again.';
        _loading = false;
      });
      SemanticsService.announce(_result, TextDirection.ltr);
    }
  }

  int _getStat(Map<String, dynamic> pokemon, String statName) {
    final stats = pokemon['stats'] as List;
    final stat = stats.firstWhere((s) => s['stat']['name'] == statName);
    return stat['base_stat'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Damage Calculator')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Semantics(
              label: 'Attacker Pokémon name input',
              child: TextField(
                controller: _attackerController,
                decoration: const InputDecoration(labelText: 'Attacker'),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Defender Pokémon name input',
              child: TextField(
                controller: _defenderController,
                decoration: const InputDecoration(labelText: 'Defender'),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Move name input',
              child: TextField(
                controller: _moveController,
                decoration: const InputDecoration(labelText: 'Move'),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'Calculate damage',
              child: ElevatedButton(
                onPressed: _loading ? null : _calculate,
                child: Text(_loading ? 'Calculating...' : 'Calculate'),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(_result, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}