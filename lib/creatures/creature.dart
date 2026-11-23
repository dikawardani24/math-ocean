/// A discoverable ocean creature with age-appropriate, grounded facts.
///
/// Facts are short on purpose: children learn through encounter, not reading.
class OceanCreature {
  const OceanCreature({
    required this.id,
    required this.name,
    required this.emoji,
    required this.habitat,
    required this.habitatId,
    required this.diet,
    required this.movement,
    required this.funFact,
    required this.appearance,
    required this.encounterLines,
  });

  final String id;
  final String name;
  final String emoji;

  /// Where this animal lives, in child-friendly words.
  final String habitat;

  /// Map / biome id (e.g. coral_cove).
  final String habitatId;

  final String diet;
  final String movement;
  final String funFact;
  final String appearance;

  /// Short narrated lines spoken during the in-world encounter.
  final List<String> encounterLines;
}
