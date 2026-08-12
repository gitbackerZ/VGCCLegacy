import 'dart:convert';
import 'package:http/http.dart' as http;

class PokeApiService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';
  List<String>? _cachedHeldItems;
  final Map<String, bool> _megaEligibilityCache = {};

  Future<Map<String, dynamic>> getPokemon(String name) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pokemon/${name.toLowerCase()}'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Pokémon not found: $name');
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

  Future<List<String>> getMovesForPokemon(String name) async {
    final data = await getPokemon(name);
    final moves = data['moves'] as List;
    return moves
        .map((m) => m['move']['name'] as String)
        .toList()
      ..sort();
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

  /// Attempts to fetch a Mega form directly by convention: {species}-mega.
  /// Returns null if no such form exists (i.e. species cannot Mega Evolve,
  /// or uses a non-standard suffix like -mega-x / -mega-y).
  Future<Map<String, int>?> getMegaBaseStats(String name) async {
    final lower = name.toLowerCase();
    for (final suffix in ['-mega', '-mega-x', '-mega-y']) {
      try {
        final data = await getPokemon('$lower$suffix');
        final stats = data['stats'] as List;
        final Map<String, int> result = {};
        for (final s in stats) {
          result[s['stat']['name']] = s['base_stat'];
        }
        return result;
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  /// Checks (and caches) whether a species has any Mega form at all,
  /// without needing a hardcoded eligibility list.
  Future<bool> hasMegaForm(String name) async {
    final lower = name.toLowerCase();
    if (_megaEligibilityCache.containsKey(lower)) {
      return _megaEligibilityCache[lower]!;
    }
    final stats = await getMegaBaseStats(lower);
    final eligible = stats != null;
    _megaEligibilityCache[lower] = eligible;
    return eligible;
  }

  Future<List<Map<String, dynamic>>> getAbilitiesForPokemon(String name) async {
    final data = await getPokemon(name);
    final abilities = data['abilities'] as List;
    return abilities.map((a) => {
      'name': a['ability']['name'] as String,
      'isHidden': a['is_hidden'] as bool,
    }).toList();
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