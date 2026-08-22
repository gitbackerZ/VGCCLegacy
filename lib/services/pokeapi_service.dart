import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pokemon_details.dart';
import 'raw_api_cache.dart';

class PokeApiService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';

  final RawApiCache _rawCache = RawApiCache();

  /// Fetches a /pokemon/{name} payload. Checks the local raw cache first
  /// (memory, then disk) — a hit means this works fully offline. Only
  /// misses hit the network. This applies equally to base forms and mega
  /// forms (e.g. "charizard-mega-x" is just another valid name), so mega
  /// forms get indexed the same way the first time they're looked up.
  Future<Map<String, dynamic>> getPokemon(
    String name, {
    bool forceRefresh = false,
  }) async {
    final key = name.toLowerCase().trim();

    if (!forceRefresh) {
      final cached = await _rawCache.get('pokemon', key);
      if (cached != null) return cached;
    }

    final response = await http.get(Uri.parse('$baseUrl/pokemon/$key'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await _rawCache.put('pokemon', key, data);
      return data;
    } else {
      throw Exception('Pokémon not found: $name');
    }
  }

  /// Fetches a /pokemon-species/{name} payload, cache-first (same pattern
  /// as [getPokemon]).
  Future<Map<String, dynamic>> getPokemonSpecies(
    String name, {
    bool forceRefresh = false,
  }) async {
    final key = name.toLowerCase().trim();

    if (!forceRefresh) {
      final cached = await _rawCache.get('pokemon-species', key);
      if (cached != null) return cached;
    }

    final response = await http.get(Uri.parse('$baseUrl/pokemon-species/$key'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await _rawCache.put('pokemon-species', key, data);
      return data;
    } else {
      throw Exception('Pokémon species not found: $name');
    }
  }

  Future<Map<String, dynamic>> getMove(String name) async {
    final formatted = name.toLowerCase().replaceAll(' ', '-');
    final response = await http.get(Uri.parse('$baseUrl/move/$formatted'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Move not found: $name');
    }
  }

  Future<List<String>> getAllSpeciesNames() async {
    final response = await http.get(Uri.parse('$baseUrl/pokemon-species?limit=2000'));
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
  Future<int> getGenderRate(String name, {bool forceRefresh = false}) async {
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
      final data = await getPokemonSpecies(baseName, forceRefresh: forceRefresh);
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

  /// All Mega-form variants for [name] (e.g. "charizard" ->
  /// "charizard-mega-x", "charizard-mega-y"), each resolved to its full
  /// [PokemonDetails] (base stats, ability, types, height, weight). Each
  /// mega form is fetched (and indexed into the local cache) through the
  /// same [getPokemonDetails] path as any base form — no separate lookup
  /// mechanism is needed since mega forms are ordinary PokeAPI pokemon
  /// entries under their own name.
  Future<Map<String, PokemonDetails>> getAllMegaFormDetails(String name) async {
    final Map<String, PokemonDetails> results = {};
    try {
      final varieties = await getVarieties(name);
      final megaVarieties = varieties.where((v) {
        final String formName = v['pokemon']['name'] ?? '';
        return formName.contains('-mega');
      });

      for (final variety in megaVarieties) {
        final String formName = variety['pokemon']['name'];
        results[formName] = await getPokemonDetails(formName);
      }
    } catch (_) {
      // Species has no mega forms or request failed
    }
    return results;
  }

  /// All move names learnable by [name] across every generation/version
  /// group PokeAPI has data for (flattened, not scoped to a specific game).
  Future<List<String>> getMovesForPokemon(String name) async {
    final data = await getPokemon(name);
    return _extractAllMoveNames(data);
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

  /// Full detail bundle: name, gender_rate, types, base_stats, abilities,
  /// height, weight, move_learn_set (flattened, all generations).
  ///
  /// Works offline once [name] has been fetched before, since every piece
  /// is derived from [getPokemon]/[getGenderRate], both of which are
  /// cache-first. Pass [forceRefresh]: true to bypass the cache for this
  /// lookup and re-pull fresh data from PokeAPI.
  Future<PokemonDetails> getPokemonDetails(
    String name, {
    bool forceRefresh = false,
  }) async {
    final data = await getPokemon(name, forceRefresh: forceRefresh);
    final heightDecimeters = (data['height'] as num).toDouble();
    final weightHectograms = (data['weight'] as num).toDouble();
    final genderRate = await getGenderRate(name, forceRefresh: forceRefresh);

    return PokemonDetails(
      name: data['name'] as String,
      genderRate: genderRate,
      types: _extractTypes(data),
      baseStats: _extractBaseStats(data),
      abilities: _extractAbilities(data),
      heightMeters: heightDecimeters / 10.0,
      weightKilograms: weightHectograms / 10.0,
      moveLearnSet: _extractAllMoveNames(data),
    );
  }

  /// Clears cached data. Pass [name] to clear just that Pokémon/species pair
  /// (e.g. after a correction); omit it to wipe the entire local index.
  Future<void> clearCache({String? name}) async {
    if (name == null) {
      await _rawCache.clear();
      return;
    }
    await _rawCache.remove('pokemon', name);
    await _rawCache.remove('pokemon-species', name);
  }

  /// Roughly how many Pokémon/forms are currently indexed on-device.
  Future<int> cachedPokemonCount() => _rawCache.count('pokemon');

  // ---- extraction helpers (operate on an already-fetched /pokemon payload) ----

  List<String> _extractTypes(Map<String, dynamic> data) {
    final types = data['types'] as List;
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

  List<String> _extractAllMoveNames(Map<String, dynamic> data) {
    final moves = data['moves'] as List;
    return moves.map((m) => m['move']['name'] as String).toList()..sort();
  }
}