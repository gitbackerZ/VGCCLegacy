import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/pokeapi_service.dart';

class TeamMember {
  final String name;
  final int pokedexNumber;
  String? heldItem;
  bool isMega;

  TeamMember({
    required this.name,
    required this.pokedexNumber,
    this.heldItem,
    this.isMega = false,
  });
}

class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({super.key});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  final _service = PokeApiService();
  final _searchController = TextEditingController();

  List<String> _allSpecies = [];
  List<String> _excludedPokemon = [];
  List<String> _megaEligible = [];
  List<String> _filtered = [];
  List<TeamMember> _team = [];

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

      setState(() {
        _allSpecies = species.where((s) => !_excludedPokemon.contains(s)).toList();
        _filtered = []; // start empty — only populate when searching
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading Pokémon data. Check your connection.';
        _loading = false;
      });
    }
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
      _announce('$name added to your team. ${_team.length} of 6 slots filled.');
    } catch (e) {
      _announce('Could not add $name. Check the name and try again.');
    }
  }

  void _removeFromTeam(int index) {
    final removed = _team[index].name;
    setState(() => _team.removeAt(index));
    _announce('$removed removed from team.');
  }

  void _setHeldItem(int index, String item) {
    final duplicate = _team.any((m) => m.heldItem == item && m != _team[index]);
    if (duplicate && item.isNotEmpty) {
      _announce('Another Pokémon on your team already holds $item. Items cannot be duplicated.');
      return;
    }
    setState(() => _team[index].heldItem = item.isEmpty ? null : item);
    _announce('${_team[index].name} is now holding $item.');
  }

  void _toggleMega(int index) {
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
    _announce('${member.name} Mega Evolution ${member.isMega ? "enabled" : "disabled"}.');
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
                  'Your team, ${_team.length} of 6: ${_team.isEmpty ? "empty" : _team.map((m) => m.isMega ? "${m.name} (Mega)" : m.name).join(", ")}',
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
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _team.length,
                itemBuilder: (context, index) {
                  final member = _team[index];
                  final eligible = _megaEligible.contains(member.name.toLowerCase());
                  return ListTile(
                    title: Text(member.name),
                    subtitle: Text(member.heldItem ?? 'No item held'),
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
                          label: 'Remove ${member.name} from team',
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeFromTeam(index),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showItemDialog(index),
                  );
                },
              ),
            ),
          const Divider(),
          Expanded(
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
            onPressed: () {
              _setHeldItem(index, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}