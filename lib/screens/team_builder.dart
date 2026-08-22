import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pokeapi_service.dart';
import '../services/stat_calculator.dart';
import '../services/team_text_codec.dart';
import '../data/natures.dart';
import '../models/team_member.dart';
import '../theme/adaptive_field_theme.dart';
import '../widgets/team_builder/team_card.dart';
import '../widgets/team_builder/pokemon_search_list.dart';
import '../dialogs/team_builder/remove_confirm_dialog.dart';
import '../dialogs/team_builder/stats_dialog.dart';
import '../dialogs/team_builder/export_dialog.dart';
import '../dialogs/team_builder/import_dialog.dart';

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
  List<String> _filtered = [];
  List<TeamMember> _team = [];

  final Map<int, List<String>> _movesCache = {};
  final Map<int, List<Map<String, dynamic>>> _abilitiesCache = {};

  final Map<int, String?> _activePanels = {};
  final Set<int> _collapsedCards = {};

  final Map<int, Map<String, TextEditingController>> _evControllers = {};
  final Map<int, Map<String, FocusNode>> _evFocusNodes = {};

  final Map<int, TextEditingController> _itemControllers = {};
  final Map<int, FocusNode> _itemFocusNodes = {};
  List<String>? _cachedValidItems;

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
    _disposeAllEvControllers();
    super.dispose();
  }

  void _disposeAllEvControllers() {
    for (final map in _evControllers.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    _evControllers.clear();
    for (final map in _evFocusNodes.values) {
      for (final n in map.values) {
        n.dispose();
      }
    }
    _evFocusNodes.clear();
    for (final c in _itemControllers.values) {
      c.dispose();
    }
    _itemControllers.clear();
    for (final n in _itemFocusNodes.values) {
      n.dispose();
    }
    _itemFocusNodes.clear();
  }

  void _disposeEvControllersForIndex(int index) {
    final controllers = _evControllers.remove(index);
    if (controllers != null) {
      for (final c in controllers.values) {
        c.dispose();
      }
    }
    final nodes = _evFocusNodes.remove(index);
    if (nodes != null) {
      for (final n in nodes.values) {
        n.dispose();
      }
    }
    _itemControllers.remove(index)?.dispose();
    _itemFocusNodes.remove(index)?.dispose();
  }

  void _ensureEvControllers(int index) {
    final member = _team[index];
    final existing = _evControllers[index];
    if (existing != null) {
      for (final stat in member.evs.keys) {
        final c = existing[stat];
        if (c != null && c.text != member.evs[stat].toString()) {
          c.text = member.evs[stat].toString();
        }
      }
      return;
    }

    final controllers = <String, TextEditingController>{};
    final nodes = <String, FocusNode>{};
    for (final stat in member.evs.keys) {
      final controller = TextEditingController(text: member.evs[stat].toString());
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          _commitEv(index, stat);
        }
      });
      controllers[stat] = controller;
      nodes[stat] = focusNode;
    }
    _evControllers[index] = controllers;
    _evFocusNodes[index] = nodes;
  }

  void _commitEv(int index, String stat) {
    final controllers = _evControllers[index];
    if (controllers == null) return;
    final controller = controllers[stat];
    if (controller == null) return;

    final parsed = int.tryParse(controller.text.trim()) ?? 0;
    _setEv(index, stat, parsed);

    final accepted = _team[index].evs[stat]!.toString();
    if (controller.text != accepted) {
      controller.text = accepted;
      controller.selection = TextSelection.collapsed(offset: accepted.length);
    }
  }

  void _ensureItemController(int index) {
    if (_itemControllers.containsKey(index)) {
      final current = _team[index].heldItem ?? '';
      final focus = _itemFocusNodes[index];
      if (focus != null && !focus.hasFocus) {
        if (_itemControllers[index]!.text != current) {
          _itemControllers[index]!.text = current;
        }
      }
      return;
    }
    final controller = TextEditingController(text: _team[index].heldItem ?? '');
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        _commitHeldItem(index);
      }
    });
    _itemControllers[index] = controller;
    _itemFocusNodes[index] = focusNode;
  }

  Future<void> _commitHeldItem(int index) async {
    final controller = _itemControllers[index];
    if (controller == null) return;
    final raw = controller.text.trim();

    if (raw.isEmpty) {
      if (_team[index].heldItem != null) {
        await _setHeldItem(index, '');
      }
      return;
    }

    try {
      _cachedValidItems ??= await _service.getHeldItemNames();
      final canonical = _resolveHeldItemName(raw);
      if (canonical != null) {
        if (_team[index].heldItem != canonical) {
          await _setHeldItem(index, canonical);
        }
        controller.text = canonical;
      } else {
        _announce('Not a recognized Champions held item.');
        controller.text = _team[index].heldItem ?? '';
      }
    } catch (_) {
      _announce('Could not validate held item.');
      controller.text = _team[index].heldItem ?? '';
    }
  }

  Future<void> _selectHeldItem(int index, String selection) async {
    if (_team[index].heldItem != selection) {
      await _setHeldItem(index, selection);
    }
  }

  Future<void> _clearHeldItem(int index) async {
    await _setHeldItem(index, '');
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

      final itemsFuture = _service.getHeldItemNames();
      await _loadSavedTeam();
      try {
        _cachedValidItems = await itemsFuture;
      } catch (_) {
        _cachedValidItems = [];
      }

      setState(() {
        _allSpecies = allowed;
        _filtered = [];
        _loading = false;
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
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? []
          : _allSpecies.where((p) => p.toLowerCase().contains(q)).toList();
    });
  }

  String? _resolveHeldItemName(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return null;
    final pool = _cachedValidItems ?? const <String>[];
    final slug = q.replaceAll(' ', '-');
    final spaced = q.replaceAll('-', ' ');
    for (final item in pool) {
      final clean = item.toLowerCase();
      if (clean == q ||
          clean == slug ||
          clean == spaced ||
          clean.replaceAll('-', ' ') == spaced) {
        return clean;
      }
    }
    return null;
  }

  Future<void> _addToTeam(String name) async {
    _unfocus();
    if (_team.length >= 6) {
      _announce('Team is full. Maximum of six Pokémon.');
      return;
    }

    try {
      final String selectedFormName = name;
      final data = await _service.getPokemon(selectedFormName);
      final pokedexNumber = data['id'] as int;

      if (_team.any((m) => m.pokedexNumber == pokedexNumber)) {
        _announce(
            '$selectedFormName shares a Pokédex number with a Pokémon already on your team.');
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
    final confirmed = await showRemoveConfirmDialog(context, name: name);
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
      _disposeEvControllersForIndex(index);

      final newCollapsed = <int>{};
      for (final i in _collapsedCards) {
        newCollapsed.add(i > index ? i - 1 : i);
      }
      _collapsedCards
        ..clear()
        ..addAll(newCollapsed);

      final newEvControllers = <int, Map<String, TextEditingController>>{};
      final newEvFocusNodes = <int, Map<String, FocusNode>>{};
      for (final entry in _evControllers.entries) {
        final i = entry.key;
        if (i == index) continue;
        final newKey = i > index ? i - 1 : i;
        newEvControllers[newKey] = entry.value;
      }
      for (final entry in _evFocusNodes.entries) {
        final i = entry.key;
        if (i == index) continue;
        final newKey = i > index ? i - 1 : i;
        newEvFocusNodes[newKey] = entry.value;
      }
      _evControllers
        ..clear()
        ..addAll(newEvControllers);
      _evFocusNodes
        ..clear()
        ..addAll(newEvFocusNodes);

      final newItemControllers = <int, TextEditingController>{};
      final newItemFocusNodes = <int, FocusNode>{};
      for (final entry in _itemControllers.entries) {
        final i = entry.key;
        if (i == index) continue;
        final newKey = i > index ? i - 1 : i;
        newItemControllers[newKey] = entry.value;
      }
      for (final entry in _itemFocusNodes.entries) {
        final i = entry.key;
        if (i == index) continue;
        final newKey = i > index ? i - 1 : i;
        newItemFocusNodes[newKey] = entry.value;
      }
      _itemControllers
        ..clear()
        ..addAll(newItemControllers);
      _itemFocusNodes
        ..clear()
        ..addAll(newItemFocusNodes);
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
        _activePanels[index] = null;
      }
    });
  }

  Future<void> _setHeldItem(int index, String item) async {
    final cleanItem = item.trim().toLowerCase();

    if (cleanItem.isNotEmpty) {
      final duplicateMember = _team.firstWhere(
        (m) => m.heldItem?.trim().toLowerCase() == cleanItem && _team.indexOf(m) != index,
        orElse: () => TeamMember(name: '', pokedexNumber: -1),
      );

      if (duplicateMember.pokedexNumber != -1) {
        _announce(
            'Item Clause Violation: ${duplicateMember.name.toUpperCase()} is already holding $cleanItem.');
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
      _activePanels[index] = _activePanels[index] == panelName ? null : panelName;
    });

    if (_activePanels[index] != null) {
      if (panelName == 'evs') {
        _ensureEvControllers(index);
      }
      if (panelName == 'details') {
        _ensureItemController(index);
        if (_cachedValidItems == null) {
          try {
            _cachedValidItems = await _service.getHeldItemNames();
          } catch (_) {}
        }
      }
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

    if (item == 'eviolite') return false;

    if (formKey.contains('-mega-x')) {
      return item.endsWith('x') && item.contains('ite');
    } else if (formKey.contains('-mega-y')) {
      return item.endsWith('y') && item.contains('ite');
    } else {
      return item.endsWith('ite') ||
          item == 'red-orb' ||
          item == 'blue-orb' ||
          item == 'red orb' ||
          item == 'blue orb';
    }
  }

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
      await showStatsDialog(
        context,
        memberName: member.name,
        gender: member.gender,
        natureName: member.nature,
        normalStats: normalStats,
        megaStats: megaStats,
        megaFormName: megaFormName,
        megaAbility: megaAbility,
      );
    } catch (e) {
      _announce('Could not load stats for ${member.name}.');
    } finally {
      _unfocus();
    }
  }

  Future<void> _showExportDialog() async {
    _unfocus();
    if (_team.isEmpty) {
      _announce('Your team is empty. Add Pokémon before exporting.');
      return;
    }

    if (!mounted) return;
    showExportLoadingDialog(context);

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
    await showExportResultDialog(context, text: text);
    _unfocus();
  }

  Future<void> _showImportDialog() async {
    _unfocus();
    final pastedText = await showImportPasteDialog(context);

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
    final mode = await showImportModeDialog(context, parsedCount: parsed.length);

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
                  style: TextStyle(color: AdaptiveFieldTheme.fieldTextColor(context)),
                  cursorColor: AdaptiveFieldTheme.cursorColor(context),
                  decoration: AdaptiveFieldTheme.inputDecoration(context, 'Search Pokémon').copyWith(
                    prefixIcon: Icon(Icons.search, color: AdaptiveFieldTheme.iconColor(context)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? Semantics(
                            button: true,
                            label: 'Clear search',
                            child: IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _filter('');
                              },
                              icon: Icon(Icons.clear, color: AdaptiveFieldTheme.iconColor(context)),
                            ),
                          )
                        : null,
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
              child: PokemonSearchList(
                query: _searchController.text,
                filtered: _filtered,
                onAdd: _addToTeam,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(int index) {
    final member = _team[index];
    return TeamCard(
      member: member,
      index: index,
      isCollapsed: _collapsedCards.contains(index),
      activePanel: _activePanels[index],
      moveOptions: _movesCache[index],
      abilityOptions: _abilitiesCache[index],
      cachedValidItems: _cachedValidItems ?? const <String>[],
      evControllers: _evControllers[index],
      evFocusNodes: _evFocusNodes[index],
      itemController: _itemControllers[index],
      itemFocus: _itemFocusNodes[index],
      onToggleCollapsed: () => _toggleCardCollapsed(index),
      onRemove: () => _confirmRemoveFromTeam(index),
      onTogglePanel: (panel) => _togglePanel(index, panel),
      onShowStats: () => _showStats(index),
      onSetMove: (slot, move) => _setMove(index, slot, move),
      onSetGender: (gender) => _setGender(index, gender),
      onSetAbility: (ability) => _setAbility(index, ability),
      onSetNature: (nature) => _setNature(index, nature),
      onCommitEv: (stat) => _commitEv(index, stat),
      onCommitHeldItem: () => _commitHeldItem(index),
      onSelectHeldItem: (selection) => _selectHeldItem(index, selection),
      onClearHeldItem: () => _clearHeldItem(index),
    );
  }
}