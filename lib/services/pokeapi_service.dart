import 'dart:convert';
import 'package:http/http.dart' as http;

class PokeApiService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';
  List<String>? _cachedHeldItems;
  final Map<String, bool> _megaEligibilityCache = {};

  /// Regional tags used in PokéAPI form identifiers
  static const List<String> regionalSuffixes = [
    '-alola',
    '-galar',
    '-hisui',
    '-paldea',
  ];

  // ==========================================
  // Core Pokémon & Species Endpoints
  // ==========================================

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

  Future<MoveData> getMove(String name) async {
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

  // ==========================================
  // Variety & Form Fetching
  // ==========================================

  /// Returns all form varieties listed under a species payload.
  Future<List<Map<String, dynamic>>> getVarieties(String speciesName) async {
    final speciesData = await getPokemonSpecies(speciesName);
    final List<dynamic> varieties = speciesData['varieties'] ?? [];
    return varieties.cast<Map<String, dynamic>>();
  }

  /// Fetches base stats for all Mega forms associated with a species (e.g. Charizard Mega X & Y).
  /// Returns a Map of form name to stats map.
  Future<Map<String, Map<String, int>>> getMegaBaseStats(String name) async {
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

  /// Checks (and caches) whether a species has any Mega form at all.
  Future<bool> hasMegaForm(String name) async {
    final lower = name.toLowerCase().trim();
    if (_megaEligibilityCache.containsKey(lower)) {
      return _megaEligibilityCache[lower]!;
    }
    final megaStats = await getMegaBaseStats(lower);
    final eligible = megaStats.isNotEmpty;
    _megaEligibilityCache[lower] = eligible;
    return eligible;
  }

  /// Fetches form names for regional variants (e.g. ['sneasel-hisui']).
  Future<List<String>> getRegionalFormNames(String speciesName) async {
    try {
      final varieties = await getVarieties(speciesName);
      return varieties
          .map((v) => v['pokemon']['name'] as String)
          .where((formName) =>
              regionalSuffixes.any((suffix) => formName.contains(suffix)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns gender information, including distinct forms (e.g. Meowstic Female)
  /// and whether the base form has sprite-level gender differences.
  Future<GenderFormInfo> getGenderFormInfo(String speciesName) async {
    final speciesData = await getPokemonSpecies(speciesName);
    final bool hasGenderDifferences =
        speciesData['has_gender_differences'] ?? false;
    final List<dynamic> varieties = speciesData['varieties'] ?? [];

    final genderVarieties = varieties
        .map((v) => v['pokemon']['name'] as String)
        .where((n) => n.contains('-female') || n.contains('-male'))
        .toList();

    return GenderFormInfo(
      hasSpriteDifferences: hasGenderDifferences,
      distinctGenderFormNames: genderVarieties,
    );
  }

  // ==========================================
  // Stat & Details Helpers
  // ==========================================

  Future<List<String>> getMovesForPokemon(String name) async {
    final data = await getPokemon(name);
    final moves = data['moves'] as List;
    return moves.map((m) => m['move']['name'] as String).toList()..sort();
  }

  Future<Map<String, int>> getBaseStats(String name) async {
    final data = await getPokemon(name);
    final stats = data['stats'] as List;
    final Map<String, int> result = {};
    for (final s in stats) {
      result[s['stat']['name']] = s['base_stat'];
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAbilitiesForPokemon(String name) async {
    final data = await getPokemon(name);
    final abilities = data['abilities'] as List;
    return abilities
        .map((a) => {
              'name': a['ability']['name'] as String,
              'isHidden': a['is_hidden'] as bool,
            })
        .toList();
  }

  Future<List<String>> getHeldItemNames() async {
    if (_cachedHeldItems != null) return _cachedHeldItems!;

    final categoriesToFetch = [
      'held-items',
      'choice',
      'type-enhancement',
      'species-specific',
      'stat-boosts',
      'baking-only',
      'plates',
      'z-crystals',
      'in-a-pinch',
      'jewels',
      'mega-stones',
      'spelunking',
      'effort-drop',
      'medicine',
      'flute',
      'vitamins',
    ];

    final Set<String> heldItems = {};

    for (final category in categoriesToFetch) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/item-category/$category'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List;
          for (final item in items) {
            heldItems.add((item['name'] as String).replaceAll('-', ' '));
          }
        }
      } catch (e) {
        continue;
      }
    }

    _cachedHeldItems = heldItems.toList()..sort();
    return _cachedHeldItems!;
  }
}

/// Simple model for gender difference results
class GenderFormInfo {
  final bool hasSpriteDifferences;
  final List<String> distinctGenderFormNames;

  GenderFormInfo({
    required this.hasSpriteDifferences,
    required this.distinctGenderFormNames,
  });
}
