class TeamMember {
  String name;
  int pokedexNumber;
  String? heldItem;
  List<String?> moves;
  String nature;
  Map<String, int> evs;
  String? ability;
  String gender;
  int genderRate; // -1 genderless, 0 always male, 8 always female, else both possible

  TeamMember({
    required this.name,
    required this.pokedexNumber,
    this.heldItem,
    List<String?>? moves,
    this.nature = 'Hardy',
    Map<String, int>? evs,
    this.ability,
    this.gender = 'Male',
    this.genderRate = 4,
  })  : moves = moves ?? List.filled(4, null),
        evs = evs ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0};

  int get evTotal => evs.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'name': name,
        'pokedexNumber': pokedexNumber,
        'heldItem': heldItem,
        'moves': moves,
        'nature': nature,
        'evs': evs,
        'ability': ability,
        'gender': gender,
        'genderRate': genderRate,
      };

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        name: json['name'],
        pokedexNumber: json['pokedexNumber'],
        heldItem: json['heldItem'],
        moves: List<String?>.from(json['moves'] ?? List.filled(4, null)),
        nature: json['nature'] ?? 'Hardy',
        evs: Map<String, int>.from(
            json['evs'] ?? {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0}),
        ability: json['ability'],
        gender: json['gender'] ?? 'Male',
        genderRate: json['genderRate'] ?? 4,
      );
}