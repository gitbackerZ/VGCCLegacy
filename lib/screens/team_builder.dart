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
  String? ability;
  String gender;

  TeamMember({
    required this.name,
    required this.pokedexNumber,
    this.heldItem,
    this.isMega = false,
    List<String?>? moves,
    this.nature = 'Hardy',
    Map<String, int>? evs,
    this.ability,
    this.gender = 'Male',
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
        'ability': ability,
        'gender': gender,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        name: json['name'],
        pokedexNumber: json['pokedexNumber'],
        heldItem: json['heldItem'],
        isMega: json['isMega'] ?? false,
        moves: List<String?>.from(json['moves'] ?? List.filled(4, null)),
        nature: json['nature'] ?? 'Hardy',
        evs: Map<String, int>.from(json['evs'] ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0}),
        ability: json['ability'],
        gender: json['gender'] ?? 'Male',
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
  final _searchFocusNode = FocusNode();
  static const _storageKey = 'saved_team';

  List<String> _allSpecies = [];
  List<String> _excludedPokemon = [];
  List<String> _filtered = [];
  List<TeamMember> _team = [];
  final Map<int, List<String>> _movesCache = {};
  final Map<int, List<Map<String, dynamic>>> _abilitiesCache = {};
  
  // Track active panel per team member: 'moves', 'details', 'evs', or null
  final Map<int, String?> _activePanels = {};

  bool _loading = true;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _unfocus() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _loadData() async {
    try {
      final rulesJson = await rootBundle.loadString('lib/data/mb_rules.json');
      final rules = json.decode(rulesJson);
      _excludedPokemon = List<String>.from(rules['excluded_pokemon']);

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
    _unfocus();
    if (_team.length >= 6) {
      _announce('Team is full. Maximum of six Pokémon.');
      return;
    }

    try {
      final varieties = await _service.getVarieties(name);

      final selectableVarieties = varieties.where((v) {
        final String vName = v['pokemon']['name'] as String;
        return !vName.contains('-mega') && !vName.contains('-gmax');
      }).map((v) => v['pokemon']['name'] as String).toList();

      String selectedFormName = name;

      if (selectableVarieties.length > 1 && mounted) {
        final chosen = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text('Select Form for ${name.toUpperCase()}'),
            children: selectableVarieties.map((formName) {
              final displayName = formName
                  .split('-')
                  .map((word) => word.isNotEmpty
                      ? '${word[0].toUpperCase()}${word.substring(1)}'
                      : '')
                  .join(' ');

              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, formName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(displayName, style: const TextStyle(fontSize: 16)),
                ),
              );
            }).toList(),
          ),
        );

        if (chosen == null) return;
        selectedFormName = chosen;
      }

      final data = await _service.getPokemon(selectedFormName);
      final pokedexNumber = data['id'] as int;

      if (_team.any((m) => m.pokedexNumber == pokedexNumber)) {
        _announce('$selectedFormName shares a Pokédex number with a Pokémon already on your team.');
        return;
      }

      List<String?> defaultMoves = List.filled(4, null);
      String? defaultAbility;

      try {
        final abilities = await _service.getAbilitiesForPokemon(selectedFormName);
        if (abilities.isNotEmpty) {
          defaultAbility = abilities.first['name'] as String;
        }
      } catch (_) {}

      try {
        final moves = await _service.getMovesForPokemon(selectedFormName);
        for (int i = 0; i < 4 && i < moves.length; i++) {
          defaultMoves[i] = moves[i];
        }
      } catch (_) {}

      String defaultGender = 'Male';
      if (selectedFormName.endsWith('-female')) {
        defaultGender = 'Female';
      }

      final newMember = TeamMember(
        name: selectedFormName,
        pokedexNumber: pokedexNumber,
        ability: defaultAbility,
        moves: defaultMoves,
        gender: defaultGender,
      );

      setState(() {
        _team.add(newMember);
        _searchController.clear();
        _filtered = [];
      });
      await _saveTeam();
      _announce('$selectedFormName added to your team.');
    } catch (e) {
      _announce('Could not add $name. Check the name and try again.');
    } finally {
      _unfocus();
    }
  }

  Future<void> _confirmRemoveFromTeam(int index) async {
    _unfocus();
    final name = _team[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Pokémon?'),
        content: Text('Remove $name from your team? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove $name'),
          ),
        ],
      ),
    );

    _unfocus();
    if (confirmed == true) {
      await _removeFromTeam(index);
    }
  }

  Future<void> _removeFromTeam(int index) async {
    final removed = _team[index].name;
    setState(() {
      _team.removeAt(index);
      _movesCache.remove(index);
      _abilitiesCache.remove(index);
      _activePanels.remove(index);
    });
    await _saveTeam();
    _announce('$removed removed from team.');
  }

  Future<void> _setHeldItem(int index, String item) async {
    final duplicate = _team.any((m) => m.heldItem == item && m != _team[index]);
    if (duplicate && item.isNotEmpty) {
      _announce('Another Pokémon on your team already holds $item.');
      return;
    }
    setState(() => _team[index].heldItem = item.isEmpty ? null : item);
    await _saveTeam();
    _announce('${_team[index].name} is now holding ${item.isEmpty ? "no item" : item}.');
  }

  Future<void> _toggleMega(int index) async {
    _unfocus();
    final member = _team[index];

    if (!member.isMega) {
      _announce('Checking Mega Evolution availability for ${member.name}...');
      final eligible = await _service.hasMegaForm(member.name);
      if (!eligible) {
        _announce('${member.name} does not have a Mega Evolution.');
        return;
      }

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

  void _togglePanel(int index, String panelName) async {
    _unfocus();
    setState(() {
      if (_activePanels[index] == panelName) {
        _activePanels[index] = null;
      } else {
        _activePanels[index] = panelName;
      }
    });

    if (_activePanels[index] != null) {
      if (!_movesCache.containsKey(index)) {
        try {
          final moves = await _service.getMovesForPokemon(_team[index].name);
          setState(() => _movesCache[index] = moves);
        } catch (_) {}
      }
      if (!_abilitiesCache.containsKey(index)) {
        try {
          final abilities = await _service.getAbilitiesForPokemon(_team[index].name);
          setState(() => _abilitiesCache[index] = abilities);
        } catch (_) {}
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
  }

  Future<void> _setAbility(int index, String ability) async {
    setState(() => _team[index].ability = ability);
    await _saveTeam();
  }

  Future<void> _setGender(int index, String gender) async {
    setState(() => _team[index].gender = gender);
    await _saveTeam();
  }

  Future<void> _setEv(int index, String stat, int value) async {
    final member = _team[index];
    final clamped = value.clamp(0, 252);
    final otherTotal = member.evTotal - member.evs[stat]!;
    final maxAllowed = (510 - otherTotal).clamp(0, 252);
    final finalValue = clamped > maxAllowed ? maxAllowed : clamped;

    setState(() => member.evs[stat] = finalValue);
    await _saveTeam();
  }

  bool _isValidMegaItem(String name, String heldItem, String formKey) {
    if (heldItem.isEmpty) return false;
    final item = heldItem.toLowerCase().trim();

    if (formKey.contains('-mega-x')) {
      return item.endsWith('x') && item.contains('ite');
    } else if (formKey.contains('-mega-y')) {
      return item.endsWith('y') && item.contains('ite');
    } else {
      return item.endsWith('ite') || item == 'red orb' || item == 'blue orb';
    }
  }

  Future<void> _showStats(int index) async {
    _unfocus();
    final member = _team[index];
    try {
      final nature = allNatures.firstWhere((n) => n.name == member.nature);

      final normalBaseStats = await _service.getBaseStats(member.name);
      final normalStats = StatCalculator.calculate(
        baseStats: normalBaseStats,
        evs: member.evs,
        natureBoosted: nature.boosted ?? '',
        natureLowered: nature.lowered ?? '',
      );

      Map<String, int>? megaStats;
      String? megaNotice;

      // Only calculate Mega stats if Mega toggle is explicitly ENABLED
      if (member.isMega) {
        final allMegaStats = await _service.getAllMegaBaseStats(member.name);
        final heldItem = (member.heldItem ?? '').toLowerCase().trim();

        if (allMegaStats.isNotEmpty) {
          Map<String, int>? selectedMegaBaseStats;

          if (allMegaStats.length == 1) {
            final formKey = allMegaStats.keys.first;
            if (_isValidMegaItem(member.name, heldItem, formKey)) {
              selectedMegaBaseStats = allMegaStats.values.first;
            } else {
              megaNotice = 'Equip the correct Mega Stone (e.g. ${member.name}ite) to calculate Mega stats.';
            }
          } else {
            for (final entry in allMegaStats.entries) {
              final formKey = entry.key;
              if (_isValidMegaItem(member.name, heldItem, formKey)) {
                selectedMegaBaseStats = entry.value;
                break;
              }
            }
            if (selectedMegaBaseStats == null) {
              megaNotice = 'Equip the corresponding Mega Stone (X or Y) to calculate Mega stats.';
            }
          }

          if (selectedMegaBaseStats != null) {
            megaStats = StatCalculator.calculate(
              baseStats: selectedMegaBaseStats,
              evs: member.evs,
              natureBoosted: nature.boosted ?? '',
              natureLowered: nature.lowered ?? '',
            );
          }
        } else {
          megaNotice = 'No Mega Evolution data found for ${member.name}.';
        }
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${member.name.toUpperCase()} — Level 50 Stats'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gender: ${member.gender} • Nature: ${member.nature}'),
                const SizedBox(height: 8),
                const Text('Assumes max IVs (31) at Level 50.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                const Text('Base Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ..._buildStatRows(normalStats, nature),
                if (member.isMega) ...[
                  const SizedBox(height: 16),
                  const Text('Mega Evolution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (megaStats != null)
                    ..._buildStatRows(megaStats, nature)
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        megaNotice ?? 'Mega Stone required.',
                        style: const TextStyle(color: Colors.orange, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ],
            ),
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
    } finally {
      _unfocus();
    }
  }

  List<Widget> _buildStatRows(Map<String, int> stats, Nature nature) {
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

    return GestureDetector(
      onTap: _unfocus,
      child: Scaffold(
        appBar: AppBar(title: const Text('Team Builder')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Semantics(
                label: 'Search Pokémon by name',
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  decoration: const InputDecoration(
                    labelText: 'Search Pokémon',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
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
                    'Your team: ${_team.length} of 6 slots filled',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
      ),
    );
  }

  Widget _buildTeamCard(int index) {
    final member = _team[index];
    final activePanel = _activePanels[index];

    final nonNullMoves = member.moves.where((m) => m != null && m.isNotEmpty).join(', ');
    final movesDisplay = nonNullMoves.isEmpty ? 'None set' : nonNullMoves;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ANNOUNCER / FINALIZED SUMMARY CONTAINER
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      member.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Row(
                      children: [
                        if (member.isMega)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('MEGA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        Text(
                          '#${member.pokedexNumber}',
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('🎒 Item: ${member.heldItem ?? "None"}', style: const TextStyle(fontSize: 13)),
                    Text('👤 Gender: ${member.gender}', style: const TextStyle(fontSize: 13)),
                    Text('⚡ Ability: ${member.ability ?? "None"}', style: const TextStyle(fontSize: 13)),
                    Text('🧠 Nature: ${member.nature}', style: const TextStyle(fontSize: 13)),
                    Text('📊 EVs: ${member.evTotal}/510', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '⚔️ Moves: $movesDisplay',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // DEDICATED TOGGLE TOOLBAR
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolbarToggle(
                  icon: Icons.backpack_outlined,
                  label: 'Item',
                  isActive: false,
                  onPressed: () => _showItemDialog(index),
                ),
                _buildToolbarToggle(
                  icon: Icons.sports_esports_outlined,
                  label: 'Moves',
                  isActive: activePanel == 'moves',
                  onPressed: () => _togglePanel(index, 'moves'),
                ),
                _buildToolbarToggle(
                  icon: Icons.tune,
                  label: 'Details',
                  isActive: activePanel == 'details',
                  onPressed: () => _togglePanel(index, 'details'),
                ),
                _buildToolbarToggle(
                  icon: Icons.bar_chart,
                  label: 'EVs',
                  isActive: activePanel == 'evs',
                  onPressed: () => _togglePanel(index, 'evs'),
                ),
                _buildToolbarToggle(
                  icon: member.isMega ? Icons.star : Icons.star_border,
                  label: 'Mega',
                  isActive: member.isMega,
                  activeColor: Colors.amber.shade800,
                  onPressed: () => _toggleMega(index),
                ),
                _buildToolbarToggle(
                  icon: Icons.analytics_outlined,
                  label: 'Stats',
                  isActive: false,
                  onPressed: () => _showStats(index),
                ),
                _buildToolbarToggle(
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  isActive: false,
                  activeColor: Colors.red,
                  onPressed: () => _confirmRemoveFromTeam(index),
                ),
              ],
            ),
          ),

          // ACTIVE CUSTOMIZATION DRAWER PANEL
          if (activePanel != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildPanelContent(index, activePanel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbarToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onPressed,
  }) {
    final color = isActive ? (activeColor ?? Theme.of(context).primaryColor) : Colors.grey.shade700;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(int index, String panelName) {
    final member = _team[index];

    if (panelName == 'moves') {
      final moveOptions = _movesCache[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configure Moveset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (moveOptions == null)
            const Center(child: CircularProgressIndicator())
          else
            ...List.generate(4, (slot) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DropdownButtonFormField<String>(
                  initialValue: member.moves[slot],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Move ${slot + 1}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...moveOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                  ],
                  onChanged: (value) => _setMove(index, slot, value),
                ),
              );
            }),
        ],
      );
    }

    if (panelName == 'details') {
      final abilityOptions = _abilitiesCache[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gender, Ability & Nature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: member.gender,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Genderless', child: Text('Genderless')),
            ],
            onChanged: (value) {
              if (value != null) _setGender(index, value);
            },
          ),
          const SizedBox(height: 12),
          if (abilityOptions == null)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<String>(
              initialValue: member.ability,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ability', border: OutlineInputBorder()),
              items: abilityOptions.map((a) {
                final label = a['isHidden'] ? '${a['name']} (Hidden)' : a['name'];
                return DropdownMenuItem<String>(value: a['name'] as String, child: Text(label));
              }).toList(),
              onChanged: (value) {
                if (value != null) _setAbility(index, value);
              },
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: member.nature,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nature', border: OutlineInputBorder()),
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
        ],
      );
    }

    if (panelName == 'evs') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Effort Values (EVs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${member.evTotal}/510 total', style: TextStyle(color: member.evTotal > 510 ? Colors.red : Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          ...member.evs.keys.map((stat) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextFormField(
                key: ValueKey('${member.name}-$stat-${member.evs[stat]}'),
                initialValue: member.evs[stat].toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '$stat EVs (0-252)',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onFieldSubmitted: (value) {
                  final parsed = int.tryParse(value) ?? 0;
                  _setEv(index, stat, parsed);
                },
              ),
            );
          }),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _showItemDialog(int index) async {
    _unfocus();
    List<String> validItems;
    try {
      validItems = await _service.getHeldItemNames();
    } catch (e) {
      _announce('Could not load valid held items. Check your connection.');
      return;
    }

    if (!mounted) return;

    final controller = TextEditingController(text: _team[index].heldItem ?? '');
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Held Item for ${_team[index].name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Held item name',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leave blank for no item. Must match an official held item name (e.g. choice band, charizardite x).',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final entered = controller.text.trim().toLowerCase();
                  if (entered.isEmpty) {
                    await _setHeldItem(index, '');
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }
                  if (validItems.contains(entered)) {
                    await _setHeldItem(index, entered);
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    setDialogState(() {
                      errorText = 'Not a recognized held item name.';
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    _unfocus();
  }
}
