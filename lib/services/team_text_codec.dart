import '../screens/team_builder.dart' show TeamMember;

class TeamTextCodec {
  static String encodeTeam(List<TeamMember> team) {
    final buffer = StringBuffer();
    for (int i = 0; i < team.length; i++) {
      final m = team[i];
      buffer.writeln('=== POKEMON ${i + 1} ===');
      buffer.writeln('Species: ${m.name}');
      buffer.writeln('Gender: ${m.gender}');
      buffer.writeln('Held Item: ${m.heldItem ?? "None"}');
      buffer.writeln('Ability: ${m.ability ?? "None"}');
      buffer.writeln('Nature: ${m.nature}');
      buffer.writeln('Mega: ${m.isMega ? "Yes" : "No"}');
      final moveList = m.moves.map((mv) => mv ?? 'None').join(', ');
      buffer.writeln('Moves: $moveList');
      final evList = m.evs.entries.map((e) => '${e.key}=${e.value}').join(', ');
      buffer.writeln('EVs: $evList');
      buffer.writeln('=== END ===');
      if (i < team.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Parses pasted text back into a list of TeamMember objects.
  /// Throws a FormatException with a descriptive message on malformed input.
  static List<TeamMember> decodeTeam(String text) {
    final List<TeamMember> result = [];
    final blocks = text.split(RegExp(r'===\s*POKEMON\s+\d+\s*==='));

    for (final rawBlock in blocks) {
      final block = rawBlock.trim();
      if (block.isEmpty) continue;

      final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      String? species;
      String gender = 'Male';
      String? heldItem;
      String? ability;
      String nature = 'Hardy';
      bool isMega = false;
      List<String?> moves = List.filled(4, null);
      Map<String, int> evs = {'HP': 0, 'Atk': 0, 'Def': 0, 'SpA': 0, 'SpD': 0, 'Spe': 0};

      for (final line in lines) {
        if (line.startsWith('===')) continue; // skip END markers

        if (line.startsWith('Species:')) {
          species = line.substring('Species:'.length).trim();
        } else if (line.startsWith('Gender:')) {
          gender = line.substring('Gender:'.length).trim();
        } else if (line.startsWith('Held Item:')) {
          final val = line.substring('Held Item:'.length).trim();
          heldItem = (val.toLowerCase() == 'none' || val.isEmpty) ? null : val.toLowerCase();
        } else if (line.startsWith('Ability:')) {
          final val = line.substring('Ability:'.length).trim();
          ability = (val.toLowerCase() == 'none' || val.isEmpty) ? null : val;
        } else if (line.startsWith('Nature:')) {
          nature = line.substring('Nature:'.length).trim();
        } else if (line.startsWith('Mega:')) {
          final val = line.substring('Mega:'.length).trim().toLowerCase();
          isMega = val == 'yes' || val == 'true';
        } else if (line.startsWith('Moves:')) {
          final val = line.substring('Moves:'.length).trim();
          final parts = val.split(',').map((p) => p.trim()).toList();
          for (int i = 0; i < 4; i++) {
            if (i < parts.length && parts[i].toLowerCase() != 'none' && parts[i].isNotEmpty) {
              moves[i] = parts[i];
            }
          }
        } else if (line.startsWith('EVs:')) {
          final val = line.substring('EVs:'.length).trim();
          final parts = val.split(',');
          for (final part in parts) {
            final kv = part.split('=');
            if (kv.length == 2) {
              final key = kv[0].trim();
              final value = int.tryParse(kv[1].trim()) ?? 0;
              if (evs.containsKey(key)) {
                evs[key] = value.clamp(0, 252);
              }
            }
          }
        }
      }

      if (species == null || species.isEmpty) {
        throw FormatException('A Pokémon block is missing a "Species:" line.');
      }

      result.add(TeamMember(
        name: species,
        pokedexNumber: 0, // will be re-resolved by caller after fetching real data
        heldItem: heldItem,
        isMega: isMega,
        moves: moves,
        nature: nature,
        evs: evs,
        ability: ability,
        gender: gender,
      ));
    }

    if (result.isEmpty) {
      throw const FormatException('No valid Pokémon blocks found in the pasted text.');
    }
    if (result.length > 6) {
      throw const FormatException('Pasted text contains more than 6 Pokémon.');
    }

    return result;
  }
}