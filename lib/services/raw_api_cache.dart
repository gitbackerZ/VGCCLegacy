import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local on-device cache for raw PokeAPI JSON payloads ('pokemon' and
/// 'pokemon-species' resources), keyed by resource type + name.
///
/// This is the single source of truth for offline access: every derived
/// getter in [PokeApiService] (stats, abilities, types, moves, gender rate,
/// mega forms, etc.) reads through [PokeApiService.getPokemon] /
/// [PokeApiService.getPokemonSpecies], which check here first. Once a
/// Pokémon (base form or mega form) has been fetched once, every one of
/// those views is servable entirely from disk with no network connection.
class RawApiCache {
  static const String _keyPrefix = 'pokeapi_raw_v1';

  final Map<String, Map<String, dynamic>> _memory = {};

  String _key(String resource, String name) =>
      '${_keyPrefix}_${resource}_${name.toLowerCase().trim()}';

  Future<Map<String, dynamic>?> get(String resource, String name) async {
    final key = _key(resource, name);
    final memHit = _memory[key];
    if (memHit != null) return memHit;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final data = json.decode(raw) as Map<String, dynamic>;
      _memory[key] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String resource, String name, Map<String, dynamic> data) async {
    final key = _key(resource, name);
    _memory[key] = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json.encode(data));
    } catch (_) {
      // Best-effort; memory cache still holds it for this session.
    }
  }

  Future<void> remove(String resource, String name) async {
    final key = _key(resource, name);
    _memory.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Clears every cached entry for [resource] ('pokemon' or 'pokemon-species').
  /// Pass null to clear everything cached by this store.
  Future<void> clear([String? resource]) async {
    final prefix = resource != null ? '${_keyPrefix}_${resource}_' : _keyPrefix;
    _memory.removeWhere((key, _) => key.startsWith(prefix));
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Number of resources of [resource] type currently cached on disk.
  Future<int> count(String resource) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = '${_keyPrefix}_${resource}_';
      return prefs.getKeys().where((k) => k.startsWith(prefix)).length;
    } catch (_) {
      return 0;
    }
  }
}