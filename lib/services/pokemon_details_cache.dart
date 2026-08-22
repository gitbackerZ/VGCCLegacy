import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pokemon_details.dart';

/// Local on-device cache for [PokemonDetails], keyed by version group + name.
///
/// Two-tier: an in-memory map for instant repeat lookups within a session,
/// backed by SharedPreferences so entries survive app restarts and avoid
/// re-fetching from PokeAPI for Pokémon already looked up before.
class PokemonDetailsCache {
  static const String _keyPrefix = 'pokemon_details_v1';

  final Map<String, PokemonDetails> _memory = {};

  String _key(String versionGroup, String name) =>
      '${_keyPrefix}_${versionGroup}_${name.toLowerCase().trim()}';

  /// Returns the cached details, checking memory first, then disk.
  /// Returns null on a full cache miss.
  Future<PokemonDetails?> get(String versionGroup, String name) async {
    final key = _key(versionGroup, name);
    final memHit = _memory[key];
    if (memHit != null) return memHit;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final details = PokemonDetails.fromJson(json.decode(raw));
      _memory[key] = details;
      return details;
    } catch (_) {
      // Malformed/stale cache entry — treat as a miss.
      return null;
    }
  }

  /// Persists [details] to memory and disk under [versionGroup] + its name.
  Future<void> put(String versionGroup, PokemonDetails details) async {
    final key = _key(versionGroup, details.name);
    _memory[key] = details;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json.encode(details.toJson()));
    } catch (_) {
      // Best-effort persistence; memory cache still holds this session's copy.
    }
  }

  /// Clears all cached Pokémon details (memory + disk) for [versionGroup].
  Future<void> clear(String versionGroup) async {
    final prefix = '${_keyPrefix}_${versionGroup}_';
    _memory.removeWhere((key, _) => key.startsWith(prefix));
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}