/// The pure maths of the Kecrekan counting frame.
///
/// The 3D scene is a view of this state, never the other way round: every bead
/// position is derived from [rodCounts], so the number on screen and the number
/// the child built can never disagree.
class KecrekanMath {
  static const int rodCount = 5;
  static const int beadsPerRod = 5;
  // Five bead centres are spaced exactly one bead diameter apart on each side of the counting gap.  Keeping the
  // travel span equal to `5 * spacing` means one counted bead moves exactly
  // one slot, matching one bead-width of finger travel.  A wider span left a
  // 2.27-slot hole between the groups: a single count flung a bead across that
  // hole and a natural drag over-counted by three or four beads.
  static const double leftX = -0.675;
  static const double rightX = 0.675;
  static const double spacing = 0.27;

  /// Minimum visible rows needed to represent a challenge's starting and
  /// ending values. A subtraction task must fit its starting value even when
  /// the number of beads moved is smaller.
  static int rowsForChallenge({required int start, required int target}) {
    final capacity = start > target ? start : target;
    final bounded = capacity.clamp(1, rodCount * beadsPerRod).toInt();
    return ((bounded + beadsPerRod - 1) ~/ beadsPerRod)
        .clamp(1, rodCount)
        .toInt();
  }

  final List<int> rodCounts = List<int>.filled(rodCount, 0);

  int get total => rodCounts.fold(0, (a, b) => a + b);

  int countFor(int rod) => rodCounts[rod];

  void setCount(int rod, int count) {
    if (rod < 0 || rod >= rodCount) return;
    rodCounts[rod] = count.clamp(0, beadsPerRod);
  }

  void add(int rod, int delta) => setCount(rod, countFor(rod) + delta);

  void clear() {
    for (var i = 0; i < rodCount; i++) {
      rodCounts[i] = 0;
    }
  }

  /// Put [value] on the frame, filling row by row from the top.
  void setTotal(int value) {
    clear();
    var left = value.clamp(0, rodCount * beadsPerRod);
    for (var rod = 0; rod < rodCount && left > 0; rod++) {
      final take = left > beadsPerRod ? beadsPerRod : left;
      rodCounts[rod] = take;
      left -= take;
    }
  }

  /// Screen-left position of bead [index] on [rod] when [count] beads are
  /// counted.
  ///
  /// Beads keep their order on the rod: index 0 starts at the screen-right
  /// end, index 4 at the screen-left end. Counted beads pack against the left
  /// side of the frame; the rest pack against the right. Exactly one empty
  /// slot separates the groups, and the five-bead marker sits in that slot at
  /// a five-bead row.
  static double beadX(int index, int count) {
    if (index >= beadsPerRod - count) {
      // Counted: highest indices sit furthest screen-left.
      final slot = beadsPerRod - 1 - index;
      return leftX + slot * spacing;
    }
    // Uncounted: index 0 sits furthest screen-right.
    return rightX - index * spacing;
  }

  /// A tap on [index] moves exactly one bead: counted beads go back, and
  /// uncounted beads join the counted group.
  static int toggledCount(int count, int index) {
    final counted = index >= beadsPerRod - count;
    return (count + (counted ? -1 : 1)).clamp(0, beadsPerRod);
  }

  /// The row count implied by dragging a bead [dx] world units from where the
  /// drag began.
  ///
  /// The result is anchored to [startCount], not accumulated frame by frame, so
  /// reversing direction retraces exactly the same counts and a slow drag can
  /// never drift. Each step needs half a bead of travel plus a small dead band
  /// [hysteresis], which stops a finger resting on a threshold from flickering
  /// between two counts.
  static int dragCount({
    required int startCount,
    required double dx,
    double hysteresis = 0.12,
  }) {
    final raw = startCount - dx / spacing;
    var count = startCount;
    // Step one slot at a time. A single huge jump would skip the intermediate
    // bead positions the spring animates through.
    while (raw > count + 0.5 + hysteresis) {
      count++;
    }
    while (raw < count - 0.5 - hysteresis) {
      count--;
    }
    return count.clamp(0, beadsPerRod);
  }

  /// The bead index that would be the next one counted (adjacent to the gap).
  static int nextUncountedIndex(int count) =>
      count >= beadsPerRod ? -1 : beadsPerRod - 1 - count;

  /// The counted bead adjacent to the gap, or -1.
  static int edgeCountedIndex(int count) =>
      count <= 0 ? -1 : beadsPerRod - count;

  /// How many beads are counted on each side of [count].
  static (int counted, int uncounted) split(int count) =>
      (count, beadsPerRod - count);
}
