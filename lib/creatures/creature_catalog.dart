import 'creature.dart';

/// Creatures introduced in the Coral Cove vertical slice.
///
/// Facts are simplified for young children but biologically grounded:
/// green sea turtles eat seagrass; clownfish shelter in anemones and eat
/// small plankton / leftovers; both belong on coral reefs.
const List<OceanCreature> kCreatures = [
  OceanCreature(
    id: 'green_turtle',
    name: 'Green Sea Turtle',
    emoji: '🐢',
    habitat: 'Warm coral reefs and seagrass meadows',
    habitatId: 'coral_cove',
    diet: 'Crunchy seagrass and soft jellyfish',
    movement: 'She rows with big flippers and comes up for air',
    funFact: 'She can hold her breath for a long swim under the waves',
    appearance: 'A smooth shell, gentle eyes, and four strong flippers',
    encounterLines: [
      'Look! A green sea turtle is swimming by.',
      'Watch her flippers. She rows through the water.',
      'She needs air, so she rises to the surface.',
      'She loves crunchy seagrass. Let’s help her find some!',
    ],
  ),
  OceanCreature(
    id: 'clownfish',
    name: 'Clownfish',
    emoji: '🐠',
    habitat: 'Coral reefs, tucked inside sea anemones',
    habitatId: 'coral_cove',
    diet: 'Tiny bits of food floating in the water',
    movement: 'He darts in and out of his anemone home',
    funFact: 'The anemone’s stingers do not hurt him — it is his safe house',
    appearance: 'Bright orange with white stripes',
    encounterLines: [
      'A clownfish peeks from the anemone!',
      'This is his home. The soft tentacles keep him safe.',
    ],
  ),
  OceanCreature(
    id: 'hermit_crab',
    name: 'Hermit Crab',
    emoji: '🦀',
    habitat: 'Sandy seabeds and tide pools',
    habitatId: 'shell_shore',
    diet: 'Scavenges tiny bits of food and algae',
    movement: 'Crawls sideways across the sandy seabed',
    funFact: 'They find empty shells from other sea animals to protect their soft bellies',
    appearance: 'Red-orange body with claw pincers',
    encounterLines: [
      'Hello! I am looking for a new shell home.',
      'I crawl sideways on the sandy floor.',
    ],
  ),
  OceanCreature(
    id: 'seahorse',
    name: 'Seahorse',
    emoji: '🐴',
    habitat: 'Giant kelp forests and seagrass beds',
    habitatId: 'kelp_forest',
    diet: 'Tiny drifting shrimp and plankton',
    movement: 'Swims upright and holds onto kelp with its tail',
    funFact: 'They wrap their tails around kelp stalks so ocean currents do not sweep them away',
    appearance: 'Horse-like head and upright swimming body',
    encounterLines: [
      'Hello from the kelp forest!',
      'I wrap my tail around the kelp so I stay safe.',
    ],
  ),
];

OceanCreature? creatureById(String id) {
  for (final creature in kCreatures) {
    if (creature.id == id) return creature;
  }
  return null;
}

List<OceanCreature> creaturesForHabitat(String habitatId) => kCreatures
    .where((c) => c.habitatId == habitatId)
    .toList(growable: false);
