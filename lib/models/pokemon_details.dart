/// A single move-learn entry: which move, how it's learned, and at what
/// level (for level-up moves only).
class LearnableMove {
  final String name;
  final String learnMethod; // e.g. 'level-up', 'machine', 'egg', 'tutor'
  final int? levelLearnedAt;

  LearnableMove({
    required this.name,
    required this.learnMethod,
    this.levelLearnedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'learnMethod': learnMethod,
        'levelLearnedAt': levelLearnedAt,
      };

  factory LearnableMove.fromJson(Map<String, dynamic> json) => LearnableMove(
        name: json['name'] as String,
        learnMethod: json['learnMethod'] as String,
        levelLearnedAt: json['levelLearnedAt'] as int?,
      );

  @override
  String toString() =>
      '$name ($learnMethod${levelLearnedAt != null && levelLearnedAt! > 0 ? ", lvl $levelLearnedAt" : ""})';
}

/// Full detail bundle for a Pokémon/form, matching the requested table:
/// name, gender_rate, types, base_stats, abilities, height, weight,
/// move_learn_set.
class PokemonDetails {
  final String name;
  final int genderRate;
  final List<String> types;
  final Map<String, int> baseStats;
  final List<Map<String, dynamic>> abilities; // {name, isHidden}
  final double heightMeters;
  final double weightKilograms;
  final List<LearnableMove> moveLearnSet;

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
        'moveLearnSet': moveLearnSet.map((m) => m.toJson()).toList(),
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
        moveLearnSet: (json['moveLearnSet'] as List)
            .map((m) => LearnableMove.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}