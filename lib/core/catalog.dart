import 'dart:math' as math;

import '../theme.dart';
import 'models.dart';

const List<Mission> kMissions = [
  // ── Coral Cove · counting ────────────────────────────────────────────────
  Mission(
    id: 'count_1',
    station: StationKind.counting,
    title: 'Bubble Bop',
    story:
        'Four shiny bubbles float up from the coral. Slide four beads to the '
        'left to count them.',
    target: 4,
    hint: 'Tap the first bead on the right side. Each tap slides one over.',
    voice:
        'Four bubbles! Slide four beads to the left. Tap a bead to slide it.',
    emoji: '💧',
  ),
  Mission(
    id: 'count_2',
    station: StationKind.counting,
    title: 'Shell Search',
    story:
        'Mina the seahorse found seven little shells in the sand. Can you '
        'slide seven beads?',
    target: 7,
    hint: 'Slide five first, then two more. Five and two make seven.',
    voice: 'Seven shells! Slide seven beads to the left.',
    emoji: '🐚',
  ),
  Mission(
    id: 'count_3',
    station: StationKind.counting,
    title: 'Fish Parade',
    story:
        'Ten silver fish swim past the reef in a row. Count every one of '
        'them with the beads.',
    target: 10,
    hint: 'Use a whole row. Ten beads all the way to the left!',
    voice: 'Ten fish! Slide ten beads. One whole row.',
    emoji: '🐟',
  ),
  Mission(
    id: 'count_4',
    station: StationKind.counting,
    title: 'Crab Count',
    story:
        'Six cheeky crabs are hiding between the rocks. Slide one bead for '
        'each crab.',
    target: 6,
    hint: 'Five beads, then one more. That makes six.',
    voice: 'Six crabs! Slide six beads to the left.',
    emoji: '🦀',
  ),

  // ── Shell Shore · addition ───────────────────────────────────────────────
  Mission(
    id: 'add_1',
    station: StationKind.addition,
    title: 'Two Pearl Piles',
    story:
        'Pearls rest beside a coral cup. More pearls arrive with the tide. '
        'How many pearls are together now?',
    target: 5,
    a: 2,
    b: 3,
    hint: 'Keep the first group together. Count the new arrivals, then think about what happens when the groups join.',
    voice: 'Look at the pearls already here. Count the new arrivals. How many pearls are together now?',
    emoji: '🐚',
  ),
  Mission(
    id: 'add_2',
    station: StationKind.addition,
    title: 'Starfish Pair',
    story:
        'Some starfish rest on one rock. Other starfish swim over to join them. '
        'How many starfish are together?',
    target: 7,
    a: 4,
    b: 3,
    hint: 'Look at the group already resting on the rock. Count the friends who join. How do the groups fit together?',
    voice: 'Some starfish are resting here. More friends join them. How many are there altogether?',
    emoji: '⭐',
  ),
  Mission(
    id: 'add_3',
    station: StationKind.addition,
    title: 'High Five',
    story:
        'A group of tiny turtles is having a rest. More friends arrive for the party. '
        'How many turtles are at the party now?',
    target: 10,
    a: 5,
    b: 5,
    hint: 'Notice the first group. Now look at the friends who arrived. What do the two groups make together?',
    voice: 'Look at the turtles already resting. More friends arrive. How many turtles are together?',
    emoji: '🐢',
  ),
  Mission(
    id: 'add_4',
    station: StationKind.addition,
    title: 'Coral Climb',
    story:
        'Coral flowers are blooming on a branch. New flowers open nearby. '
        'How many flowers can you see altogether?',
    target: 8,
    a: 6,
    b: 2,
    hint: 'Keep the flowers already blooming in mind. Look at the new flowers. How many can you see altogether?',
    voice: 'Some flowers are blooming already. New flowers open nearby. How many can you see altogether?',
    emoji: '🌺',
  ),

  // ── Kelp Forest · subtraction ────────────────────────────────────────────
  Mission(
    id: 'sub_1',
    station: StationKind.subtraction,
    title: 'Bubble Pop',
    story:
        'Bubbles float above the reef. Some bubbles pop and disappear. '
        'How many bubbles are still floating?',
    target: 5,
    start: 8,
    b: 3,
    hint: 'Look closely at the bubbles that are still floating. Which ones have disappeared? How many remain?',
    voice: 'Watch the bubbles. Some pop and disappear. How many are still floating?',
    emoji: '💧',
  ),
  Mission(
    id: 'sub_2',
    station: StationKind.subtraction,
    title: 'Shells Away',
    story:
        'Shells rest on the shore. A wave sweeps some back into the sea. '
        'How many shells remain on the sand?',
    target: 6,
    start: 10,
    b: 4,
    hint: 'Look at the shells still on the sand. Compare them with the group you started with. How many remain?',
    voice: 'A wave sweeps some shells away. How many are left on the sand?',
    emoji: '🐚',
  ),
  Mission(
    id: 'sub_3',
    station: StationKind.subtraction,
    title: 'Kelp Snack',
    story:
        'Kelp leaves are growing. A fish nibbles some leaves. '
        'How many leaves are still growing?',
    target: 5,
    start: 7,
    b: 2,
    hint: 'Look at the leaves still growing. Which leaves did the fish nibble? How many remain?',
    voice: 'A fish nibbles some leaves. How many are still growing?',
    emoji: '🌿',
  ),
  Mission(
    id: 'sub_4',
    station: StationKind.subtraction,
    title: 'Turtle Trek',
    story:
        'Baby turtles swim together. Some dive down to explore the deep sea. '
        'How many turtles keep swimming near the surface?',
    target: 4,
    start: 9,
    b: 5,
    hint: 'Watch the turtles that dive away. Count the ones that keep swimming near the surface.',
    voice: 'Some turtles dive into the deep sea. How many keep swimming near the surface?',
    emoji: '🐢',
  ),

  // ── Finger Reef · Jarimatika ─────────────────────────────────────────────
  Mission(
    id: 'jar_1',
    station: StationKind.jarimatika,
    title: 'Three Fingers',
    story:
        'Open your right hand. Show three with your fingers — your index, '
        'middle and ring finger.',
    target: 3,
    hint: 'Right hand counts ones: index = 1, add middle = 2, add ring = 3.',
    voice: 'Show three with your right hand. Index, middle and ring finger.',
    emoji: '✋',
  ),
  Mission(
    id: 'jar_2',
    station: StationKind.jarimatika,
    title: 'Six Magic Fingers',
    story:
        'Six is a special Jarimatika shape: thumb and index together. Can '
        'you make six?',
    target: 6,
    hint: 'Thumb plus index finger makes six on the right hand.',
    voice: 'Show six. Thumb and index finger together.',
    emoji: '🤙',
  ),
  Mission(
    id: 'jar_3',
    station: StationKind.jarimatika,
    title: 'Eight in a Row',
    story:
        'Open four fingers and add the thumb. That is the Jarimatika way '
        'to show eight.',
    target: 8,
    hint: 'Thumb, index, middle and ring — four fingers plus the thumb.',
    voice: 'Show eight. Thumb and four fingers.',
    emoji: '🖐️',
  ),
  Mission(
    id: 'jar_4',
    station: StationKind.jarimatika,
    title: 'Ten at Last',
    story:
        'Ten moves to the other hand. Show one finger on your left hand — '
        'that means one ten.',
    target: 10,
    hint: 'Left hand counts tens. One left finger = ten.',
    voice: 'Show ten. One finger on your left hand.',
    emoji: '🙌',
  ),
];

/// Creates a fresh challenge instead of asking a child to pick a fixed
/// answer from a mission list. Kecrekan addition/subtraction stay within ten;
/// Jarimatika uses both hands for a two-digit number.
Mission randomChallengeFor(StationKind kind, {math.Random? random}) {
  final rng = random ?? math.Random();
  switch (kind) {
    case StationKind.counting:
      final target = 1 + rng.nextInt(20);
      return Mission(
        id: 'challenge_count_$target',
        station: kind,
        title: 'Treasure Count',
        story: 'A group of ocean treasures is waiting. Count them with the beads.',
        target: target,
        voice: 'Look carefully at the treasures. How many can you count?',
        hint: 'Move the beads one at a time and count the group.',
        emoji: '🐚',
      );
    case StationKind.addition:
      final a = 1 + rng.nextInt(9);
      final b = 1 + rng.nextInt(10 - a);
      return Mission(
        id: 'challenge_add_${a}_$b',
        station: kind,
        title: 'Pearl Gathering',
        story: 'Some pearls are here. More pearls arrive. How many are together?',
        target: a + b,
        a: a,
        b: b,
        voice: 'Look at the pearls already here. More arrive. How many altogether?',
        hint: 'Keep the first group. Join the new arrivals and count them together.',
        emoji: '🐚',
      );
    case StationKind.subtraction:
      final start = 2 + rng.nextInt(9);
      final removed = 1 + rng.nextInt(start - 1);
      return Mission(
        id: 'challenge_sub_${start}_$removed',
        station: kind,
        title: 'Tide Takes Treasures',
        story: 'Some treasures drift away with the tide. How many are left?',
        target: start - removed,
        start: start,
        b: removed,
        voice: 'Watch some treasures drift away. How many remain?',
        hint: 'Move away the treasures that disappeared, then count what remains.',
        emoji: '🫧',
      );
    case StationKind.jarimatika:
      final target = 10 + rng.nextInt(90);
      return Mission(
        id: 'challenge_jar_$target',
        station: kind,
        title: 'Finger Number Challenge',
        story: 'Show this number with both Jarimatika hands.',
        target: target,
        voice: 'Show $target with your Jarimatika hands. Left hand is tens, right hand is ones.',
        hint: 'Left hand shows tens. Right hand shows ones.',
        emoji: '✋',
      );
  }
}

List<Mission> missionsFor(StationKind kind) =>
    kMissions.where((m) => m.station == kind).toList(growable: false);

Mission? missionById(String id) {
  for (final m in kMissions) {
    if (m.id == id) return m;
  }
  return null;
}

const List<Treasure> kTreasures = [
  Treasure(
    id: 'pearl',
    name: 'Moon Pearl',
    emoji: '💧',
    blurb: 'It hums a tiny song when the tide turns.',
    color: OceanColors.foam,
  ),
  Treasure(
    id: 'starfish',
    name: 'Sunset Starfish',
    emoji: '⭐',
    blurb: 'Warm as the last ray of sunshine on the reef.',
    color: OceanColors.sunny,
  ),
  Treasure(
    id: 'seashell',
    name: 'Whisper Shell',
    emoji: '🐚',
    blurb: 'Hold it close to hear the ocean say your name.',
    color: OceanColors.coral,
  ),
  Treasure(
    id: 'seahorse',
    name: 'Tiny Seahorse',
    emoji: '🐠',
    blurb: 'Mina’s cousin. Loves to dance in the current.',
    color: OceanColors.aqua,
  ),
  Treasure(
    id: 'jelly',
    name: 'Lantern Jelly',
    emoji: '🎐',
    blurb: 'Glows like a nightlight under the waves.',
    color: OceanColors.lilac,
  ),
  Treasure(
    id: 'crab',
    name: 'Clickety Crab',
    emoji: '🦀',
    blurb: 'Counts its shell collection every single morning.',
    color: OceanColors.coralDeep,
  ),
  Treasure(
    id: 'dolphin',
    name: 'Dolphin Whistle',
    emoji: '🐬',
    blurb: 'A silver whistle that calls a friendly pod.',
    color: OceanColors.teal,
  ),
  Treasure(
    id: 'octopus',
    name: 'Inky Octopus',
    emoji: '🐙',
    blurb: 'Can juggle eight pearls at once. Show-off.',
    color: OceanColors.lilacDeep,
  ),
  Treasure(
    id: 'coral',
    name: 'Coral Crown',
    emoji: '🌺',
    blurb: 'Grown from a single kindness. Worn by the reef queen.',
    color: OceanColors.coral,
  ),
  Treasure(
    id: 'conch',
    name: 'Golden Conch',
    emoji: '🐚',
    blurb: 'Its spiral holds one hundred tiny stories.',
    color: OceanColors.sunnyDeep,
  ),
  Treasure(
    id: 'charm',
    name: 'Turtle Charm',
    emoji: '🐢',
    blurb: 'Tala’s lucky shell. She trusts you with it.',
    color: OceanColors.mint,
  ),
  Treasure(
    id: 'crown',
    name: 'Ocean Crown',
    emoji: '👑',
    blurb: 'For the kindest counter in all of Numberland.',
    color: OceanColors.sunny,
  ),
];

Treasure treasureById(String id) =>
    kTreasures.firstWhere((t) => t.id == id, orElse: () => kTreasures.first);
