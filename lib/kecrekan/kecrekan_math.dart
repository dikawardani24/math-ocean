/// The pure maths of the Kecrekan counting frame.
///
/// The 3D scene is a view of this state, never the other way round: every bead
/// position is derived from [rodCounts], so the number on screen and the number
/// the child built can never disagree.
class KecrekanMath {
  static const int rodCount = 10;
  static const int beadsPerRod = 10;
  static const double leftX = -1.24;
  static const double rightX = 1.24;
  static const double spacing = 0.22;

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
  /// end, index 9 at the screen-left end. Counted beads pack against the left
  /// side of the frame; the rest pack against the right. The half-bead of
  /// slack per row is the visible gap that makes a five-and-five split read at
  /// a glance.
  static double beadX(int index, int count) {
    if (index >= beadsPerRod - count) {
      // Counted: highest indices sit furthest screen-left.
      final slot = beadsPerRod - 1 - index;
      return leftX + slot * spacing;
    }
    // Uncounted: index 0 sits furthest screen-right.
    return rightX - index * spacing;
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
