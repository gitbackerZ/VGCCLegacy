import 'dart:convert';
import 'package:http/http.dart' as http;

class PokeApiService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';

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
}