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
        'Two pearls in one pile and three in another. Slide all of them '
        'together to find the total.',
    target: 5,
    a: 2,
    b: 3,
    hint: 'Slide two beads, then three more. Count them all.',
    voice: 'Two plus three. Slide two beads, then three more.',
    emoji: '🐚',
  ),
  Mission(
    id: 'add_2',
    station: StationKind.addition,
    title: 'Starfish Pair',
    story:
        'Four starfish on the left rock and three on the right rock. How '
        'many starfish altogether?',
    target: 7,
    a: 4,
    b: 3,
    hint: 'Four beads and three beads. Count the whole group.',
    voice: 'Four plus three. How many beads altogether?',
    emoji: '⭐',
  ),
  Mission(
    id: 'add_3',
    station: StationKind.addition,
    title: 'High Five',
    story:
        'Five tiny turtles meet five more turtles. Slide all ten beads to '
        'see the whole party.',
    target: 10,
    a: 5,
    b: 5,
    hint: 'Five beads plus five beads fills a whole row.',
    voice: 'Five plus five. Slide ten beads altogether.',
    emoji: '🐢',
  ),
  Mission(
    id: 'add_4',
    station: StationKind.addition,
    title: 'Coral Climb',
    story:
        'Six coral flowers grow on one branch and two on another. Slide the '
        'beads to add them.',
    target: 8,
    a: 6,
    b: 2,
    hint: 'Start with six. Slide two more. What number did you land on?',
    voice: 'Six plus two. Slide six beads, then two more.',
    emoji: '🌺',
  ),

  // ── Kelp Forest · subtraction ────────────────────────────────────────────
  Mission(
    id: 'sub_1',
    station: StationKind.subtraction,
    title: 'Bubble Pop',
    story:
        'Eight bubbles are floating. Three pop! Slide three beads back to '
        'the right to see how many are left.',
    target: 5,
    start: 8,
    b: 3,
    hint: 'The beads start at eight. Slide three away to the right.',
    voice: 'Eight take away three. Slide three beads back to the right.',
    emoji: '💧',
  ),
  Mission(
    id: 'sub_2',
    station: StationKind.subtraction,
    title: 'Shells Away',
    story:
        'Ten shells sit on the shore. A wave carries four away. How many '
        'shells stay?',
    target: 6,
    start: 10,
    b: 4,
    hint: 'Start with all ten beads on the left. Slide four back.',
    voice: 'Ten take away four. Slide four beads back to the right.',
    emoji: '🐚',
  ),
  Mission(
    id: 'sub_3',
    station: StationKind.subtraction,
    title: 'Kelp Snack',
    story:
        'Seven little leaves are on the kelp. A hungry fish nibbles two. '
        'Slide two beads away.',
    target: 5,
    start: 7,
    b: 2,
    hint: 'Seven beads start on the left. Slide two to the right.',
    voice: 'Seven take away two. Slide two beads back.',
    emoji: '🌿',
  ),
  Mission(
    id: 'sub_4',
    station: StationKind.subtraction,
    title: 'Turtle Trek',
    story:
        'Nine baby turtles start the race. Five dive into the deep. How '
        'many keep swimming?',
    target: 4,
    start: 9,
    b: 5,
    hint: 'Nine beads on the left. Slide five away.',
    voice: 'Nine take away five. Slide five beads back to the right.',
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
