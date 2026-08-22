import 'package:flutter/material.dart';

class PokemonSearchList extends StatelessWidget {
  final String query;
  final List<String> filtered;
  final void Function(String name) onAdd;

  const PokemonSearchList({
    super.key,
    required this.query,
    required this.filtered,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Start typing above to search for Pokémon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No Pokémon match "${query.trim()}".',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final name = filtered[index];
        return Semantics(
          button: true,
          label: 'Add $name to team',
          child: ListTile(
            dense: true,
            title: Text(name),
            onTap: () => onAdd(name),
          ),
        );
      },
    );
  }
}