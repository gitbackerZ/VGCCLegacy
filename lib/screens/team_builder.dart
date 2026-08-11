import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pokeapi_service.dart';
import '../services/stat_calculator.dart';
import '../data/natures.dart';

class TeamMember {
  String name;
  int pokedexNumber;
  String? heldItem;
  bool isMega;
  List<String?> moves;
  String nature;
  Map<String, int> evs;

  TeamMember({
    required this.name,
    required this.pokedexNumber,
    this.heldItem,
    this.isMega = false,
    List<String?>? moves,
    this.nature = 'Hardy',
    Map<String, int>? evs,
  })  : moves = moves ?? List.filled(4, null),
        evs = evs ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0};

  int get evTotal => evs.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'name': name,
        'pokedexNumber': pokedexNumber,
        'heldItem': heldItem,
        'isMega': isMega,
        'moves': moves,
        'nature': nature,
        'evs': evs,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        name: json['name'],
        pokedexNumber: json['pokedexNumber'],
        heldItem: json['heldItem'],
        isMega: json['isMega'] ?? false,
        moves: List<String?>.from(json['moves'] ?? List.filled(4, null)),
        nature: json['nature'] ?? 'Hardy',
        evs: Map<String, int>.from(json['evs'] ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0}),
      );
}

class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({super.key});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  final _service = PokeApiService();
  final _searchController = TextEditingController();
  static const _storageKey = 'saved_team';

  List<String> _allSpecies = [];
  List<String> _excludedPokemon = [];
  List<String> _megaEligible = [];
  List<String> _filtered = [];
  List<TeamMember> _team = [];
  Map<int, List<String>> _movesCache = {};
  int? _expandedIndex;

  bool _loading = true;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final rulesJson = await rootBundle.loadString('lib/data/mb_rules.json');
      final rules = json.decode(rulesJson);
      _excludedPokemon = List<String>.from(rules['excluded_pokemon']);
      _megaEligible = List<String>.from(rules['mega_eligible']);

      final species = await _service.getAllSpeciesNames();

      await _loadSavedTeam();

      setState(() {
        _allSpecies = species.where((s) => !_excludedPokemon.contains(s)).toList();
        _filtered = [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading Pokémon data. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _loadSavedTeam() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      final List<dynamic> decoded = json.decode(saved);
      _team = decoded.map((m) => TeamMember.fromJson(m)).toList();
    }
  }

  Future<void> _saveTeam() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_team.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  void _filter(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filtered = [];
      } else {
        _filtered = _allSpecies
            .where((p) => p.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _addToTeam(String name) async {
    if (_team.length >= 6) {
      _announce('Team is full. Maximum of six Pokémon.');
      return;
    }

    try {
      final data = await _service.getPokemon(name);
      final pokedexNumber = data['id'] as int;

      if (_team.any((m) => m.pokedexNumber == pokedexNumber)) {
        _announce('$name shares a Pokédex number with a Pokémon already on your team. Not allowed under species clause.');
        return;
      }

      setState(() {
        _team.add(TeamMember(name: name, pokedexNumber: pokedexNumber));
      });
      await _saveTeam();
      _announce('$name added to your team. ${_team.length} of 6 slots filled.');
    } catch (e) {
      _announce('Could not add $name. Check the name and try again.');
    }
  }

  Future<void> _removeFromTeam(int index) async {
    final removed = _team[index].name;
    setState(() {
      _team.removeAt(index);
      _movesCache.remove(index);
      if (_expandedIndex == index) _expandedIndex = null;
    });
    await _saveTeam();
    _announce('$removed removed from team.');
  }

  Future<void> _setHeldItem(int index, String item) async {
    final duplicate = _team.any((m) => m.heldItem == item && m != _team[index]);
    if (duplicate && item.isNotEmpty) {
      _announce('Another Pokémon on your team already holds $item. Items cannot be duplicated.');
      return;
    }
    setState(() => _team[index].heldItem = item.isEmpty ? null : item);
    await _saveTeam();
    _announce('${_team[index].name} is now holding $item.');
  }

  Future<void> _toggleMega(int index) async {
    final member = _team[index];
    final isEligible = _megaEligible.contains(member.name.toLowerCase());

    if (!isEligible) {
      _announce('${member.name} does not have a Mega Evolution in Regulation M-B.');
      return;
    }

    if (!member.isMega) {
      final alreadyMega = _team.any((m) => m.isMega);
      if (alreadyMega) {
        _announce('Only one Pokémon can Mega Evolve per battle. Un-select the other Mega first.');
        return;
      }
    }

    setState(() => member.isMega = !member.isMega);
    await _saveTeam();
    _announce('${member.name} Mega Evolution ${member.isMega ? "enabled" : "disabled"}.');
  }

  Future<void> _toggleExpanded(int index) async {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
    if (_expandedIndex == index && !_movesCache.containsKey(index)) {
      try {
        final moves = await _service.getMovesForPokemon(_team[index].name);
        setState(() => _movesCache[index] = moves);
      } catch (e) {
        _announce('Could not load moves for ${_team[index].name}.');
      }
    }
  }

  Future<void> _setMove(int teamIndex, int moveSlot, String? move) async {
    setState(() => _team[teamIndex].moves[moveSlot] = move);
    await _saveTeam();
  }

  Future<void> _setNature(int index, String nature) async {
    setState(() => _team[index].nature = nature);
    await _saveTeam();
    _announce('${_team[index].name}\'s nature set to $nature.');
  }

  Future<void> _setEv(int index, String stat, int value) async {
    final member = _team[index];
    final clamped = value.clamp(0, 252);
    final otherTotal = member.evTotal - member.evs[stat]!;
    final maxAllowed = (510 - otherTotal).clamp(0, 252);
    final finalValue = clamped > maxAllowed ? maxAllowed : clamped;

    setState(() => member.evs[stat] = finalValue);
    await _saveTeam();

    if (clamped > maxAllowed) {
      _announce('EV total capped at 510. $stat set to $finalValue.');
    }
  }

  Future<void> _showStats(int index) async {
    final member = _team[index];
    try {
      final baseStats = await _service.getBaseStats(member.name);
      final nature = allNatures.firstWhere((n) => n.name == member.nature);
      final finalStats = StatCalculator.calculate(
        baseStats: baseStats,
        evs: member.evs,
        natureBoosted: nature.boosted ?? '',
        natureLowered: nature.lowered ?? '',
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${member.name.toUpperCase()} — Level 50 Stats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nature: ${member.nature}'),
              const SizedBox(height: 8),
              const Text('Assumes max IVs (31) at Level 50.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              ...finalStats.entries.map((e) {
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
                  label: '${e.key}: ${e.value}${isBoosted ? ", boosted by nature" : ""}${isLowered ? ", lowered by nature" : ""}',
                  child: Text('${e.key}: ${e.value}$suffix'),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _announce('Could not load stats for ${member.name}.');
    }
  }

  void _announce(String message) {
    setState(() => _statusMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team Builder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Team Builder')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Semantics(
              label: 'Search Pokémon by name',
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: 'Search Pokémon'),
                onChanged: _filter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Your team, ${_team.length} of 6',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Semantics(
                liveRegion: true,
                child: Text(_statusMessage, style: const TextStyle(color: Colors.blue)),
              ),
            ),
          if (_team.isNotEmpty)
            Expanded(
              flex: 3,
              child: ListView.builder(
                itemCount: _team.length,
                itemBuilder: (context, index) => _buildTeamCard(index),
              ),
            ),
          const Divider(),
          Expanded(
            flex: 2,
            child: _searchController.text.trim().isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Start typing above to search for Pokémon.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final name = _filtered[index];
                      return Semantics(
                        button: true,
                        label: 'Add $name to team',
                        child: ListTile(
                          title: Text(name),
                          onTap: () => _addToTeam(name),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(int index) {
    final member = _team[index];
    final eligible = _megaEligible.contains(member.name.toLowerCase());
    final isExpanded = _expandedIndex == index;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            title: Text(member.name.toUpperCase()),
            subtitle: Text('${member.heldItem ?? "No item"} • ${member.nature} • EVs: ${member.evTotal}/510'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eligible)
                  Semantics(
                    button: true,
                    label: member.isMega
                        ? 'Disable Mega Evolution for ${member.name}'
                        : 'Enable Mega Evolution for ${member.name}',
                    child: IconButton(
                      icon: Icon(member.isMega ? Icons.star : Icons.star_border),
                      onPressed: () => _toggleMega(index),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: 'Show stats for ${member.name}',
                  child: IconButton(
                    icon: const Icon(Icons.bar_chart),
                    onPressed: () => _showStats(index),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Remove ${member.name} from team',
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeFromTeam(index),
                  ),
                ),
                Semantics(
                  button: true,
                  label: isExpanded ? 'Collapse ${member.name} details' : 'Expand ${member.name} details',
                  child: IconButton(
                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => _toggleExpanded(index),
                  ),
                ),
              ],
            ),
            onTap: () => _showItemDialog(index),
          ),
          if (isExpanded) _buildExpandedDetails(index),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(int index) {
    final member = _team[index];
    final moveOptions = _movesCache[index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moves', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (moveOptions == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            )
          else
            ...List.generate(4, (slot) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Semantics(
                  label: 'Move slot ${slot + 1} for ${member.name}',
                  child: DropdownButtonFormField<String>(
                    initialValue: member.moves[slot],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Move ${slot + 1}'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...moveOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                    ],
                    onChanged: (value) => _setMove(index, slot, value),
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          const Text('Nature', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Semantics(
            label: 'Nature for ${member.name}',
            child: DropdownButtonFormField<String>(
              initialValue: member.nature,
              isExpanded: true,
              items: allNatures.map((n) {
                final desc = n.boosted == null
                    ? '${n.name} (neutral)'
                    : '${n.name} (+${n.boosted}, -${n.lowered})';
                return DropdownMenuItem(value: n.name, child: Text(desc));
              }).toList(),
              onChanged: (value) {
                if (value != null) _setNature(index, value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('EVs (${member.evTotal}/510)', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...member.evs.keys.map((stat) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Semantics(
                label: '$stat EVs for ${member.name}, currently ${member.evs[stat]}',
                child: TextFormField(
                  key: ValueKey('${member.name}-$stat-${member.evs[stat]}'),
                  initialValue: member.evs[stat].toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: stat),
                  onFieldSubmitted: (value) {
                    final parsed = int.tryParse(value) ?? 0;
                    _setEv(index, stat, parsed);
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showItemDialog(int index) {
    final controller = TextEditingController(text: _team[index].heldItem ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Held item for ${_team[index].name}'),
        content: Semantics(
          label: 'Enter held item name',
          child: TextField(controller: controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _setHeldItem(index, controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}