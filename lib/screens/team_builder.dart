import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pokeapi_service.dart';
import '../services/stat_calculator.dart';
import '../services/team_text_codec.dart';
import '../data/natures.dart';

class TeamMember {
  String name;
  int pokedexNumber;
  String? heldItem;
  List<String?> moves;
  String nature;
  Map<String, int> evs;
  String? ability;
  String gender;
  int genderRate; // -1 genderless, 0 always male, 8 always female, else both possible

  TeamMember({
    required this.name,
    required this.pokedexNumber,
    this.heldItem,
    List<String?>? moves,
    this.nature = 'Hardy',
    Map<String, int>? evs,
    this.ability,
    this.gender = 'Male',
    this.genderRate = 4,
  })  : moves = moves ?? List.filled(4, null),
        evs = evs ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0};

  int get evTotal => evs.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'name': name,
        'pokedexNumber': pokedexNumber,
        'heldItem': heldItem,
        'moves': moves,
        'nature': nature,
        'evs': evs,
        'ability': ability,
        'gender': gender,
        'genderRate': genderRate,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        name: json['name'],
        pokedexNumber: json['pokedexNumber'],
        heldItem: json['heldItem'],
        moves: List<String?>.from(json['moves'] ?? List.filled(4, null)),
        nature: json['nature'] ?? 'Hardy',
        evs: Map<String, int>.from(json['evs'] ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0}),
        ability: json['ability'],
        gender: json['gender'] ?? 'Male',
        genderRate: json['genderRate'] ?? 4,
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

  final Map<int, String?> _activePanels = {};
  final Set<int> _collapsedCards = {}; // cards that are collapsed (summary only)

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
      final rosterJson = await rootBundle.loadString('lib/data/champions_roster.json');
      final roster = json.decode(rosterJson);
      final List<String> allowed = List<String>.from(roster['allowed_pokemon']);

      await _loadSavedTeam();

      setState(() {
        _allSpecies = allowed;
        _filtered = [];
        _loading = false;
        // Start all cards collapsed for max space efficiency
        for (int i = 0; i < _team.length; i++) {
          _collapsedCards.add(i);
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading Pokémon roster.';
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
                  child: Semantics(
                    button: true,
                    label: 'Select form $displayName',
                    child: Text(displayName, style: const TextStyle(fontSize: 16)),
                  ),
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

      final genderRate = await _service.getGenderRate(selectedFormName);
      String defaultGender;
      if (genderRate == -1) {
        defaultGender = 'Genderless';
      } else if (selectedFormName.endsWith('-female')) {
        defaultGender = 'Female';
      } else {
        defaultGender = 'Male';
      }

      final newMember = TeamMember(
        name: selectedFormName,
        pokedexNumber: pokedexNumber,
        ability: defaultAbility,
        moves: defaultMoves,
        gender: defaultGender,
        genderRate: genderRate,
      );

      setState(() {
        _team.add(newMember);
        _collapsedCards.add(_team.length - 1);
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
      _collapsedCards.remove(index);
      // Re-key collapsed/panel sets since indices shift after removal
      final newCollapsed = <int>{};
      for (final i in _collapsedCards) {
        newCollapsed.add(i > index ? i - 1 : i);
      }
      _collapsedCards
        ..clear()
        ..addAll(newCollapsed);
    });
    await _saveTeam();
    _announce('$removed removed from team.');
  }

  void _toggleCardCollapsed(int index) {
    setState(() {
      if (_collapsedCards.contains(index)) {
        _collapsedCards.remove(index);
      } else {
        _collapsedCards.add(index);
        _activePanels[index] = null; // also close any open sub-panel
      }
    });
  }

  Future<void> _setHeldItem(int index, String item) async {
    final cleanItem = item.trim().toLowerCase();

    if (cleanItem.isNotEmpty) {
      // Check if another member on the team is already holding this item
      final duplicateMember = _team.firstWhere(
        (m) => m.heldItem?.trim().toLowerCase() == cleanItem && _team.indexOf(m) != index,
        orElse: () => TeamMember(name: '', pokedexNumber: -1),
      );

      if (duplicateMember.pokedexNumber != -1) {
        _announce('Item Clause Violation: ${duplicateMember.name.toUpperCase()} is already holding $cleanItem.');
        return;
      }
    }

    setState(() => _team[index].heldItem = cleanItem.isEmpty ? null : cleanItem);
    await _saveTeam();
    _announce('${_team[index].name} is now holding ${cleanItem.isEmpty ? "no item" : cleanItem}.');
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

  bool _isValidMegaItem(String heldItem, String formKey) {
    if (heldItem.isEmpty) return false;
    final item = heldItem.toLowerCase().trim();

    // Guard against non-Mega item ending in 'ite'
    if (item == 'eviolite') return false;

    if (formKey.contains('-mega-x')) {
      return item.endsWith('x') && item.contains('ite');
    } else if (formKey.contains('-mega-y')) {
      return item.endsWith('y') && item.contains('ite');
    } else {
      return item.endsWith('ite') || item == 'red orb' || item == 'blue orb';
    }
  }

  /// Determines the active Mega form (if any) based purely on held item.
  /// Returns (formName, baseStats) or null if not currently Mega Evolved.
  Future<MapEntry<String, Map<String, int>>?> _resolveActiveMega(TeamMember member) async {
    final heldItem = (member.heldItem ?? '').toLowerCase().trim();
    if (heldItem.isEmpty) return null;

    final allMegaStats = await _service.getAllMegaBaseStats(member.name);
    if (allMegaStats.isEmpty) return null;

    for (final entry in allMegaStats.entries) {
      if (_isValidMegaItem(heldItem, entry.key)) {
        return MapEntry(entry.key, entry.value);
      }
    }
    return null;
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
      String? megaFormName;
      String? megaAbility;

      final activeMega = await _resolveActiveMega(member);
      if (activeMega != null) {
        megaFormName = activeMega.key;
        megaStats = StatCalculator.calculate(
          baseStats: activeMega.value,
          evs: member.evs,
          natureBoosted: nature.boosted ?? '',
          natureLowered: nature.lowered ?? '',
        );
        try {
          final abilities = await _service.getAbilitiesForPokemon(megaFormName);
          if (abilities.isNotEmpty) {
            megaAbility = abilities.first['name'] as String;
          }
        } catch (_) {}
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
                if (megaStats != null) ...[
                  const SizedBox(height: 16),
                  Text('Mega Evolution: $megaFormName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (megaAbility != null) Text('Ability: $megaAbility', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  ..._buildStatRows(megaStats, nature),
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    'No Mega Evolution active. Hold the correct Mega Stone to Mega Evolve.',
                    style: const TextStyle(color: Colors.orange, fontSize: 13, fontStyle: FontStyle.italic),
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

  Future<void> _showExportDialog() async {
    _unfocus();
    if (_team.isEmpty) {
      _announce('Your team is empty. Add Pokémon before exporting.');
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Calculating stats...'),
          ],
        ),
      ),
    );

    final Map<int, Map<String, int>> baseStatsByIndex = {};
    final Map<int, Map<String, int>?> megaStatsByIndex = {};
    final Map<int, String?> megaFormNameByIndex = {};
    final Map<int, String?> megaAbilityByIndex = {};

    for (int i = 0; i < _team.length; i++) {
      final member = _team[i];
      try {
        final nature = allNatures.firstWhere((n) => n.name == member.nature);
        final baseStats = await _service.getBaseStats(member.name);
        baseStatsByIndex[i] = StatCalculator.calculate(
          baseStats: baseStats,
          evs: member.evs,
          natureBoosted: nature.boosted ?? '',
          natureLowered: nature.lowered ?? '',
        );

        final activeMega = await _resolveActiveMega(member);
        if (activeMega != null) {
          megaFormNameByIndex[i] = activeMega.key;
          megaStatsByIndex[i] = StatCalculator.calculate(
            baseStats: activeMega.value,
            evs: member.evs,
            natureBoosted: nature.boosted ?? '',
            natureLowered: nature.lowered ?? '',
          );
          try {
            final abilities = await _service.getAbilitiesForPokemon(activeMega.key);
            if (abilities.isNotEmpty) {
              megaAbilityByIndex[i] = abilities.first['name'] as String;
            }
          } catch (_) {}
        }
      } catch (_) {
        // Skip stats for this member if fetch fails; export continues without them.
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // close loading dialog

    final text = TeamTextCodec.encodeTeam(
      _team,
      baseStatsByIndex,
      megaStatsByIndex,
      megaFormNameByIndex,
      megaAbilityByIndex,
    );

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Team'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Semantics(
              label: 'Team export text',
              child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    _unfocus();
  }

  Future<void> _showImportDialog() async {
    _unfocus();
    final controller = TextEditingController();
    final pastedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Team'),
        content: Semantics(
          label: 'Paste team text here',
          textField: true,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Paste exported team text here',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Parse'),
          ),
        ],
      ),
    );

    if (pastedText == null || pastedText.trim().isEmpty) {
      _unfocus();
      return;
    }

    List<TeamMember> parsed;
    try {
      parsed = TeamTextCodec.decodeTeam(pastedText);
    } catch (e) {
      _announce('Could not parse pasted text: ${e.toString()}');
      _unfocus();
      return;
    }

    if (!mounted) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Mode'),
        content: Text('Found ${parsed.length} Pokémon in the pasted text. How should this be applied?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: const Text('Add to Team'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Replace Team'),
          ),
        ],
      ),
    );

    if (mode == null || mode == 'cancel') {
      _unfocus();
      return;
    }

    if (mode == 'replace') {
      setState(() {
        _team.clear();
        _movesCache.clear();
        _abilitiesCache.clear();
        _activePanels.clear();
        _collapsedCards.clear();
      });
    }

    int added = 0;
    int failed = 0;
    for (final member in parsed) {
      if (_team.length >= 6) break;
      try {
        final data = await _service.getPokemon(member.name);
        member.pokedexNumber = data['id'] as int;
        member.genderRate = await _service.getGenderRate(member.name);
        if (_team.any((m) => m.pokedexNumber == member.pokedexNumber)) {
          failed++;
          continue;
        }
        setState(() {
          _team.add(member);
          _collapsedCards.add(_team.length - 1);
        });
        added++;
      } catch (e) {
        failed++;
      }
    }

    await _saveTeam();
    _announce('Import complete. $added Pokémon added${failed > 0 ? ", $failed failed or skipped" : ""}.');
    _unfocus();
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
        appBar: AppBar(
          title: const Text('Team Builder'),
          actions: [
            Semantics(
              button: true,
              label: 'Export team as text',
              child: IconButton(
                icon: const Icon(Icons.upload_outlined),
                onPressed: _showExportDialog,
              ),
            ),
            Semantics(
              button: true,
              label: 'Import team from text',
              child: IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: _showImportDialog,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                    isDense: true,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_statusMessage, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ),
            if (_team.isNotEmpty)
              Expanded(
                flex: 5,
                child: ListView.builder(
                  itemCount: _team.length,
                  itemBuilder: (context, index) => _buildTeamCard(index),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: _searchController.text.trim().isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Start typing above to search for Pokémon.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
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
                            dense: true,
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
    final isCollapsed = _collapsedCards.contains(index);

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
          // COMPACT HEADER: name, collapse toggle, remove toggle — always visible
          Semantics(
            label:
                '${member.name}. Item: ${member.heldItem ?? "none"}. Gender: ${member.gender}. Ability: ${member.ability ?? "none"}. Nature: ${member.nature}. EVs: ${member.evTotal} of 510. Moves: $movesDisplay.',
            child: InkWell(
              onTap: () => _toggleCardCollapsed(index),
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
                      label: isCollapsed ? 'Expand ${member.name} details' : 'Collapse ${member.name} details',
                      child: IconButton(
                        icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => _toggleCardCollapsed(index),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Remove ${member.name} from team',
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => _confirmRemoveFromTeam(index),
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
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolbarToggle(
                    icon: Icons.backpack_outlined,
                    label: 'Item',
                    isActive: false,
                    semanticLabel: 'Edit held item for ${member.name}. Currently ${member.heldItem ?? "no item"}.',
                    onPressed: () => _showItemDialog(index),
                  ),
                  _buildToolbarToggle(
                    icon: Icons.sports_esports_outlined,
                    label: 'Moves',
                    isActive: activePanel == 'moves',
                    semanticLabel: activePanel == 'moves'
                        ? 'Collapse moveset editor for ${member.name}'
                        : 'Expand moveset editor for ${member.name}',
                    onPressed: () => _togglePanel(index, 'moves'),
                  ),
                  _buildToolbarToggle(
                    icon: Icons.tune,
                    label: 'Details',
                    isActive: activePanel == 'details',
                    semanticLabel: activePanel == 'details'
                        ? 'Collapse gender, ability, and nature editor for ${member.name}'
                        : 'Expand gender, ability, and nature editor for ${member.name}',
                    onPressed: () => _togglePanel(index, 'details'),
                  ),
                  _buildToolbarToggle(
                    icon: Icons.bar_chart,
                    label: 'EVs',
                    isActive: activePanel == 'evs',
                    semanticLabel: activePanel == 'evs'
                        ? 'Collapse effort value editor for ${member.name}'
                        : 'Expand effort value editor for ${member.name}',
                    onPressed: () => _togglePanel(index, 'evs'),
                  ),
                  _buildToolbarToggle(
                    icon: Icons.analytics_outlined,
                    label: 'Stats',
                    isActive: false,
                    semanticLabel: 'Show calculated stats for ${member.name}',
                    onPressed: () => _showStats(index),
                  ),
                ],
              ),
            ),
            if (activePanel != null) ...[
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: _buildPanelContent(index, activePanel),
              ),
            ],
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
    String? semanticLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultColor = colorScheme.onSurfaceVariant;
    final color = isActive ? (activeColor ?? colorScheme.primary) : defaultColor;

    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      selected: isActive,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                ),
              ],
            ),
          ),
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
          const Text('Configure Moveset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          if (moveOptions == null)
            const Center(child: CircularProgressIndicator())
          else
            ...List.generate(4, (slot) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Semantics(
                  label: 'Move slot ${slot + 1} for ${member.name}',
                  child: DropdownButtonFormField<String>(
                    initialValue: member.moves[slot],
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Move ${slot + 1}',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...moveOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                    ],
                    onChanged: (value) => _setMove(index, slot, value),
                  ),
                ),
              );
            }),
        ],
      );
    }

    if (panelName == 'details') {
      final abilityOptions = _abilitiesCache[index];

      List<DropdownMenuItem<String>> genderItems;
      if (member.genderRate == -1) {
        genderItems = const [DropdownMenuItem(value: 'Genderless', child: Text('Genderless'))];
      } else if (member.genderRate == 0) {
        genderItems = const [DropdownMenuItem(value: 'Male', child: Text('Male'))];
      } else if (member.genderRate == 8) {
        genderItems = const [DropdownMenuItem(value: 'Female', child: Text('Female'))];
      } else {
        genderItems = const [
          DropdownMenuItem(value: 'Male', child: Text('Male')),
          DropdownMenuItem(value: 'Female', child: Text('Female')),
        ];
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gender, Ability & Nature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Semantics(
            label: 'Gender for ${member.name}, currently ${member.gender}',
            child: DropdownButtonFormField<String>(
              initialValue: member.gender,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), isDense: true),
              items: genderItems,
              onChanged: genderItems.length > 1
                  ? (value) {
                      if (value != null) _setGender(index, value);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          if (abilityOptions == null)
            const Center(child: CircularProgressIndicator())
          else
            Semantics(
              label: 'Ability for ${member.name}, currently ${member.ability ?? "none"}',
              child: DropdownButtonFormField<String>(
                initialValue: member.ability,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ability', border: OutlineInputBorder(), isDense: true),
                items: abilityOptions.map((a) {
                  final label = a['isHidden'] ? '${a['name']} (Hidden)' : a['name'];
                  return DropdownMenuItem<String>(value: a['name'] as String, child: Text(label));
                }).toList(),
                onChanged: (value) {
                  if (value != null) _setAbility(index, value);
                },
              ),
            ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Nature for ${member.name}, currently ${member.nature}',
            child: DropdownButtonFormField<String>(
              initialValue: member.nature,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Nature', border: OutlineInputBorder(), isDense: true),
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
              const Text('Effort Values (EVs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${member.evTotal}/510 total',
                  style: TextStyle(
                    fontSize: 13,
                    color: member.evTotal > 510 ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...member.evs.keys.map((stat) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Semantics(
                label: '$stat effort values, currently ${member.evs[stat]} out of 252',
                textField: true,
                child: TextFormField(
                  key: ValueKey('${member.name}-$stat-${member.evs[stat]}'),
                  initialValue: member.evs[stat].toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '$stat EVs (0-252)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value) ?? 0;
                    _setEv(index, stat, parsed);
                  },
                ),
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
                Semantics(
                  label: 'Enter held item name',
                  textField: true,
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Held item name',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
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
                  final rawEntered = controller.text.trim().toLowerCase();
                  if (rawEntered.isEmpty) {
                    await _setHeldItem(index, '');
                    if (context.mounted) Navigator.pop(context);
                    return;
                  }

                  // Normalize spaces and hyphens for flexible user input
                  final normalizedSlug = rawEntered.replaceAll(' ', '-');
                  final normalizedSpace = rawEntered.replaceAll('-', ' ');

                  final isMatch = validItems.any((item) {
                    final cleanItem = item.toLowerCase();
                    return cleanItem == rawEntered ||
                        cleanItem == normalizedSlug ||
                        cleanItem == normalizedSpace;
                  });

                  if (isMatch) {
                    await _setHeldItem(index, rawEntered);
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