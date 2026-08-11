class Nature {
  final String name;
  final String? boosted;
  final String? lowered;

  const Nature(this.name, this.boosted, this.lowered);
}

const List<Nature> allNatures = [
  Nature('Hardy', null, null),
  Nature('Lonely', 'Attack', 'Defense'),
  Nature('Brave', 'Attack', 'Speed'),
  Nature('Adamant', 'Attack', 'Sp. Atk'),
  Nature('Naughty', 'Attack', 'Sp. Def'),
  Nature('Bold', 'Defense', 'Attack'),
  Nature('Docile', null, null),
  Nature('Relaxed', 'Defense', 'Speed'),
  Nature('Impish', 'Defense', 'Sp. Atk'),
  Nature('Lax', 'Defense', 'Sp. Def'),
  Nature('Timid', 'Speed', 'Attack'),
  Nature('Hasty', 'Speed', 'Defense'),
  Nature('Serious', null, null),
  Nature('Jolly', 'Speed', 'Sp. Atk'),
  Nature('Naive', 'Speed', 'Sp. Def'),
  Nature('Modest', 'Sp. Atk', 'Attack'),
  Nature('Mild', 'Sp. Atk', 'Defense'),
  Nature('Quiet', 'Sp. Atk', 'Speed'),
  Nature('Bashful', null, null),
  Nature('Rash', 'Sp. Atk', 'Sp. Def'),
  Nature('Calm', 'Sp. Def', 'Attack'),
  Nature('Gentle', 'Sp. Def', 'Defense'),
  Nature('Sassy', 'Sp. Def', 'Speed'),
  Nature('Careful', 'Sp. Def', 'Sp. Atk'),
  Nature('Quirky', null, null),
];