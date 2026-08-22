/// Full detail bundle for a Pokémon/form, matching: name, gender_rate,
/// types, base_stats, abilities, height, weight, move_learn_set.
///
/// move_learn_set is a flattened, all-generation list of move names (not
/// scoped to any particular version group) — matching how PokeAPI's raw
/// `moves` list is naturally deduplicated (one entry per move regardless of
/// how many games it's learnable in).
class PokemonDetails {
  final String name;
  final int genderRate;
  final List<String> types;
  final Map<String, int> baseStats;
  final List<Map<String, dynamic>> abilities; // {name, isHidden}
  final double heightMeters;
  final double weightKilograms;
  final List<String> moveLearnSet;

  PokemonDetails({
    required this.name,
    required this.genderRate,
    required this.types,
    required this.baseStats,
    required this.abilities,
    required this.heightMeters,
    required this.weightKilograms,
    required this.moveLearnSet,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'genderRate': genderRate,
        'types': types,
        'baseStats': baseStats,
        'abilities': abilities,
        'heightMeters': heightMeters,
        'weightKilograms': weightKilograms,
        'moveLearnSet': moveLearnSet,
      };

  factory PokemonDetails.fromJson(Map<String, dynamic> json) => PokemonDetails(
        name: json['name'] as String,
        genderRate: json['genderRate'] as int,
        types: List<String>.from(json['types'] as List),
        baseStats: Map<String, int>.from(json['baseStats'] as Map),
        abilities: (json['abilities'] as List)
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList(),
        heightMeters: (json['heightMeters'] as num).toDouble(),
        weightKilograms: (json['weightKilograms'] as num).toDouble(),
        moveLearnSet: List<String>.from(json['moveLearnSet'] as List),
      );
}