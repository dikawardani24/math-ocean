import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/creatures/creature_catalog.dart';

void main() {
  test('every creature has required educational fields', () {
    expect(kCreatures, isNotEmpty);
    for (final creature in kCreatures) {
      expect(creature.id, isNotEmpty);
      expect(creature.name, isNotEmpty);
      expect(creature.habitat, isNotEmpty);
      expect(creature.habitatId, isNotEmpty);
      expect(creature.diet, isNotEmpty);
      expect(creature.movement, isNotEmpty);
      expect(creature.funFact, isNotEmpty);
      expect(creature.appearance, isNotEmpty);
      expect(creature.encounterLines, isNotEmpty);
    }
  });

  test('Coral Cove creatures belong on a reef', () {
    final cove = creaturesForHabitat('coral_cove');
    expect(cove.map((c) => c.id), containsAll(['green_turtle', 'clownfish']));
    for (final creature in cove) {
      expect(
        creature.habitat.toLowerCase(),
        anyOf(contains('reef'), contains('seagrass'), contains('anemone')),
      );
    }
  });

  test('creatureById finds known friends', () {
    expect(creatureById('green_turtle')?.name, 'Green Sea Turtle');
    expect(creatureById('missing'), isNull);
  });
}
