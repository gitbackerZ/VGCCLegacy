import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pokemon_details.dart';
import 'pokemon_details_cache.dart';

class PokeApiService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';

  /// PokeAPI version_group name for Gen 9 main-series games. Used to scope
  /// move-learn data to what's actually legal in Champions (Scarlet/Violet),
  /// instead of the unfiltered, all-generations move list PokeAPI returns
  /// by default. Filtering by name (not numeric id) because version_group
  /// ids are not guaranteed stable as PokeAPI adds more groups over time.
  static const String currentVersionGroup = 'scarlet-violet';

  final PokemonDetailsCache _detailsCache = PokemonDetailsCache();

  Future<Map<String, dynamic>> getPokemon(String name) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pokemon/${name.toLowerCase().trim()}'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Pokémon not found: $name');
    }
  }

  Future<Map<String, dynamic>> getPokemonSpecies(String name) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pokemon-species/${name.toLowerCase().trim()}'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Pokémon species not found: $name');
    }
  }

  Future<Map<String, dynamic>> getMove(String name) async {
    final formatted = name.toLowerCase().replaceAll(' ', '-');
    final response = await http.get(
      Uri.parse('$baseUrl/move/$formatted'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Move not found: $name');
    }
  }

  Future<List<String>> getAllSpeciesNames() async {
    final response = await http.get(
      Uri.parse('$baseUrl/pokemon-species?limit=2000'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      return results.map((r) => r['name'] as String).toList();
    } else {
      throw Exception('Could not load species list');
    }
  }

  /// Returns gender_rate: -1 = genderless, 0 = always male, 8 = always female,
  /// otherwise a female-chance ratio out of 8 (both genders possible).
  Future<int> getGenderRate(String name) async {
    // Species-level data applies even to forms; strip common form suffixes first.
    String baseName = name.toLowerCase().trim();
    for (final suffix in [
      '-mega-x',
      '-mega-y',
      '-mega',
      '-gmax',
      '-female',
      '-male'
    ]) {
      if (baseName.endsWith(suffix)) {
        baseName = baseName.substring(0, baseName.length - suffix.length);
        break;
      }
    }
    try {
      final data = await getPokemonSpecies(baseName);
      return data['gender_rate'] as int;
    } catch (e) {
      return 4; // fallback: assume both genders possible
    }
  }

  Future<List<Map<String, dynamic>>> getVarieties(String speciesName) async {
    final speciesData = await getPokemonSpecies(speciesName);
    final List<dynamic> varieties = speciesData['varieties'] ?? [];
    return varieties.cast<Map<String, dynamic>>();
  }

  Future<Map<String, Map<String, int>>> getAllMegaBaseStats(String name) async {
    final Map<String, Map<String, int>> results = {};
    try {
      final varieties = await getVarieties(name);
      final megaVarieties = varieties.where((v) {
        final String formName = v['pokemon']['name'] ?? '';
        return formName.contains('-mega');
      });

      for (final variety in megaVarieties) {
        final String formName = variety['pokemon']['name'];
        final stats = await getBaseStats(formName);
        results[formName] = stats;
      }
    } catch (_) {
      // Species has no mega forms or request failed
    }
    return results;
  }

  /// Move names learnable by [name], scoped to [versionGroup] (defaults to
  /// the current Champions ruleset's generation). Deduplicated and sorted.
  ///
  /// PokeAPI's raw `moves` list is NOT scoped to any generation by default —
  /// it includes every version_group a move has ever been learnable in
  /// (currently 32 groups spanning Gen 1 through Gen 9 plus side titles).
  /// This filters down to just [versionGroup] so the move picker only shows
  /// moves that are actually legal right now.
  Future<List<String>> getMovesForPokemon(
    String name, {
    String versionGroup = currentVersionGroup,
  }) async {
    final data = await getPokemon(name);
    return _extractMoveNamesForVersionGroup(data, versionGroup);
  }

  /// Full move-learn set (move + method + level) for [name], scoped to
  /// [versionGroup]. Use this instead of [getMovesForPokemon] when you need
  /// to distinguish level-up vs. machine vs. egg vs. tutor moves.
  Future<List<LearnableMove>> getMoveLearnSet(
    String name, {
    String versionGroup = currentVersionGroup,
  }) async {
    final data = await getPokemon(name);
    return _extractMoveLearnSet(data, versionGroup);
  }

  Future<Map<String, int>> getBaseStats(String name) async {
    final data = await getPokemon(name);
    return _extractBaseStats(data);
  }

  Future<List<Map<String, dynamic>>> getAbilitiesForPokemon(String name) async {
    final data = await getPokemon(name);
    return _extractAbilities(data);
  }

  Future<List<String>> getTypesForPokemon(String name) async {
    final data = await getPokemon(name);
    return _extractTypes(data);
  }

  /// Full detail bundle matching: name, gender_rate, types, base_stats,
  /// abilities, height, weight, move_learn_set.
  ///
  /// Checks the local cache first (memory, then disk) and only hits PokeAPI
  /// on a genuine miss, so repeated lookups for the same Pokémon — across
  /// screens, sessions, or app restarts — don't re-fetch. Pass
  /// [forceRefresh]: true to bypass the cache and re-pull from the network.
  Future<PokemonDetails> getPokemonDetails(
    String name, {
    String versionGroup = currentVersionGroup,
    bool forceRefresh = false,
  }) async {
    final normalizedName = name.toLowerCase().trim();

    if (!forceRefresh) {
      final cached = await _detailsCache.get(versionGroup, normalizedName);
      if (cached != null) return cached;
    }

    final data = await getPokemon(normalizedName);
    final heightDecimeters = (data['height'] as num).toDouble();
    final weightHectograms = (data['weight'] as num).toDouble();
    final genderRate = await getGenderRate(normalizedName);

    final details = PokemonDetails(
      name: data['name'] as String,
      genderRate: genderRate,
      types: _extractTypes(data),
      baseStats: _extractBaseStats(data),
      abilities: _extractAbilities(data),
      heightMeters: heightDecimeters / 10.0,
      weightKilograms: weightHectograms / 10.0,
      moveLearnSet: _extractMoveLearnSet(data, versionGroup),
    );

    await _detailsCache.put(versionGroup, details);
    return details;
  }

  /// Wipes the cached details for [versionGroup] (defaults to current),
  /// forcing the next lookup for every Pokémon to re-fetch from PokeAPI.
  Future<void> clearPokemonDetailsCache({
    String versionGroup = currentVersionGroup,
  }) =>
      _detailsCache.clear(versionGroup);

  // ---- extraction helpers (operate on an already-fetched /pokemon payload) ----

  List<String> _extractTypes(Map<String, dynamic> data) {
    final types = data['types'] as List;
    // Preserve official slot ordering (primary type first).
    final sorted = List<dynamic>.from(types)
      ..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));
    return sorted.map((t) => t['type']['name'] as String).toList();
  }

  Map<String, int> _extractBaseStats(Map<String, dynamic> data) {
    final stats = data['stats'] as List;
    final Map<String, int> result = {};
    for (final s in stats) {
      result[s['stat']['name']] = s['base_stat'];
    }
    return result;
  }

  List<Map<String, dynamic>> _extractAbilities(Map<String, dynamic> data) {
    final abilities = data['abilities'] as List;
    return abilities
        .map((a) => {
              'name': a['ability']['name'] as String,
              'isHidden': a['is_hidden'] as bool,
            })
        .toList();
  }

  List<LearnableMove> _extractMoveLearnSet(
    Map<String, dynamic> data,
    String versionGroup,
  ) {
    final moves = data['moves'] as List;
    final List<LearnableMove> result = [];

    for (final m in moves) {
      final String moveName = m['move']['name'] as String;
      final versionGroupDetails = m['version_group_details'] as List;

      for (final vgd in versionGroupDetails) {
        final String vgName = vgd['version_group']['name'] as String;
        if (vgName != versionGroup) continue;

        final String method = vgd['move_learn_method']['name'] as String;
        final int level = vgd['level_learned_at'] as int;

        result.add(LearnableMove(
          name: moveName,
          learnMethod: method,
          levelLearnedAt: level > 0 ? level : null,
        ));
      }
    }

    // A move can appear via multiple methods (e.g. level-up AND machine) —
    // keep all distinct (name, method, level) combos but drop exact duplicates.
    final seen = <String>{};
    final deduped = <LearnableMove>[];
    for (final lm in result) {
      final key = '${lm.name}|${lm.learnMethod}|${lm.levelLearnedAt}';
      if (seen.add(key)) deduped.add(lm);
    }

    deduped.sort((a, b) => a.name.compareTo(b.name));
    return deduped;
  }

  List<String> _extractMoveNamesForVersionGroup(
    Map<String, dynamic> data,
    String versionGroup,
  ) {
    final learnSet = _extractMoveLearnSet(data, versionGroup);
    final names = learnSet.map((lm) => lm.name).toSet().toList()..sort();
    return names;
  }
}