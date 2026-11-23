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
        'Two pearls rest beside a coral cup. Three more pearls arrive from the tide. '
        'How many pearls are together now?',
    target: 5,
    a: 2,
    b: 3,
    hint: 'Look at the pearls that were already here. What changes when the new pearls join them?',
    voice: 'Two pearls are here. Three more arrive. How many pearls are together now?',
    emoji: '🐚',
  ),
  Mission(
    id: 'add_2',
    station: StationKind.addition,
    title: 'Starfish Pair',
    story:
        'Four starfish rest on one rock. Three starfish swim over to join them. '
        'How many starfish are together?',
    target: 7,
    a: 4,
    b: 3,
    hint: 'Notice the group that is already together. What happens when the other group joins?',
    voice: 'Four starfish are resting here. Three more join them. How many are there altogether?',
    emoji: '⭐',
  ),
  Mission(
    id: 'add_3',
    station: StationKind.addition,
    title: 'High Five',
    story:
        'Five tiny turtles are having a rest. Five friends arrive for the party. '
        'How many turtles are at the party now?',
    target: 10,
    a: 5,
    b: 5,
    hint: 'A group of five is already here. Another group of five arrives. Think about how the two groups make a new total.',
    voice: 'Five turtles meet five more turtles. How many turtles are together?',
    emoji: '🐢',
  ),
  Mission(
    id: 'add_4',
    station: StationKind.addition,
    title: 'Coral Climb',
    story:
        'Six coral flowers are blooming on a branch. Two new flowers open nearby. '
        'How many flowers can you see altogether?',
    target: 8,
    a: 6,
    b: 2,
    hint: 'The frame already shows the first group. Add the new flowers to that group. What is the total?',
    voice: 'Six flowers are blooming. Two more open. How many flowers are blooming now?',
    emoji: '🌺',
  ),

  // ── Kelp Forest · subtraction ────────────────────────────────────────────
  Mission(
    id: 'sub_1',
    station: StationKind.subtraction,
    title: 'Bubble Pop',
    story:
        'Eight bubbles float above the reef. Three bubbles pop and disappear. '
        'How many bubbles are still floating?',
    target: 5,
    start: 8,
    b: 3,
    hint: 'Watch which bubbles disappear. How many are left after they pop?',
    voice: 'Eight bubbles are floating. Three pop. How many are still floating?',
    emoji: '💧',
  ),
  Mission(
    id: 'sub_2',
    station: StationKind.subtraction,
    title: 'Shells Away',
    story:
        'Ten shells rest on the shore. A wave sweeps four shells back into the sea. '
        'How many shells remain on the sand?',
    target: 6,
    start: 10,
    b: 4,
    hint: 'Some shells have been swept away. Compare the shells that remain with the starting group.',
    voice: 'Ten shells are here. Four wash away. How many are left?',
    emoji: '🐚',
  ),
  Mission(
    id: 'sub_3',
    station: StationKind.subtraction,
    title: 'Kelp Snack',
    story:
        'Seven little kelp leaves are growing. A fish nibbles two leaves. '
        'How many leaves are still growing?',
    target: 5,
    start: 7,
    b: 2,
    hint: 'Look at the leaves that are still on the kelp. How many remain after the fish eats?',
    voice: 'Seven leaves grow on the kelp. A fish eats two. How many remain?',
    emoji: '🌿',
  ),
  Mission(
    id: 'sub_4',
    station: StationKind.subtraction,
    title: 'Turtle Trek',
    story:
        'Nine baby turtles swim together. Five dive down to explore the deep sea. '
        'How many turtles keep swimming near the surface?',
    target: 4,
    start: 9,
    b: 5,
    hint: 'Some turtles have dived away. How many are still swimming here?',
    voice: 'Nine turtles swim together. Five dive away. How many are still here?',
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
