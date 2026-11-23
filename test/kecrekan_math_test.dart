import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/kecrekan/kecrekan_math.dart';

void main() {
  group('KecrekanMath', () {
    test('starts empty and counts up to one hundred', () {
      final math = KecrekanMath();
      expect(math.total, 0);
      math.setTotal(100);
      expect(math.total, 100);
      expect(math.rodCounts.every((c) => c == 10), isTrue);
    });

    test('fills rows from the top', () {
      final math = KecrekanMath();
      math.setTotal(13);
      expect(math.rodCounts.take(3), [10, 3, 0]);
      expect(math.total, 13);
    });

    test('clamps a row to ten beads', () {
      final math = KecrekanMath();
      math.setCount(0, 99);
      expect(math.countFor(0), 10);
      math.add(0, -50);
      expect(math.countFor(0), 0);
    });

    test('bead order never swaps', () {
      for (var count = 0; count <= 10; count++) {
        final positions = [
          for (var i = 0; i < 10; i++) KecrekanMath.beadX(i, count),
        ];
        for (var i = 1; i < positions.length; i++) {
          expect(
            positions[i],
            lessThan(positions[i - 1]),
            reason: 'bead $i should sit further left than ${i - 1}',
          );
        }
      }
    });

    test('the five split leaves exactly one empty slot', () {
      final positions = [for (var i = 0; i < 10; i++) KecrekanMath.beadX(i, 5)];
      final gap = positions[4] - positions[5];
      // One empty slot between the groups; the bead that crosses it moves by
      // one spacing, not by the old two-and-a-bit spacing hole.
      expect(gap, closeTo(2 * KecrekanMath.spacing, 0.0001));
      expect(gap, closeTo(0.44, 0.0001));
      expect(positions.first, KecrekanMath.rightX);
      expect(positions.last, KecrekanMath.leftX);
    });

    test('one count moves the crossing bead exactly one slot', () {
      for (var count = 0; count < 10; count++) {
        final crossing = 9 - count;
        final before = KecrekanMath.beadX(crossing, count);
        final after = KecrekanMath.beadX(crossing, count + 1);
        expect(
          before - after,
          closeTo(KecrekanMath.spacing, 1e-9),
          reason: 'count $count -> ${count + 1} should move one slot only',
        );
      }
    });

    test('the ten slots fill the packing span exactly', () {
      expect(
        KecrekanMath.rightX - KecrekanMath.leftX,
        closeTo(10 * KecrekanMath.spacing, 1e-9),
      );
      // At rest the left-most uncounted bead sits exactly one slot from the
      // left stop, so the first drag has somewhere to go.
      expect(
        KecrekanMath.beadX(9, 0),
        closeTo(KecrekanMath.leftX + KecrekanMath.spacing, 1e-9),
      );
    });

    test('counted beads pack to the left and uncounted to the right', () {
      expect(
        KecrekanMath.beadX(9, 0),
        KecrekanMath.rightX - 9 * KecrekanMath.spacing,
      );
      expect(KecrekanMath.beadX(9, 10), KecrekanMath.leftX);
      expect(
        KecrekanMath.beadX(0, 10),
        KecrekanMath.leftX + 9 * KecrekanMath.spacing,
      );
    });

    test('edge helpers point at the bead next to the gap', () {
      expect(KecrekanMath.nextUncountedIndex(0), 9);
      expect(KecrekanMath.nextUncountedIndex(10), -1);
      expect(KecrekanMath.edgeCountedIndex(0), -1);
      expect(KecrekanMath.edgeCountedIndex(5), 5);
    });
  });

  group('tap', () {
    test('moves exactly one bead in the expected direction', () {
      // Uncounted bead joins the counted group.
      expect(KecrekanMath.toggledCount(0, 9), 1);
      expect(KecrekanMath.toggledCount(4, 5), 5);
      // Counted bead goes back.
      expect(KecrekanMath.toggledCount(5, 5), 4);
      expect(KecrekanMath.toggledCount(10, 0), 9);
    });

    test('never leaves the rod range', () {
      expect(KecrekanMath.toggledCount(10, 9), 9);
      expect(KecrekanMath.toggledCount(0, 0), 1);
      for (var count = 0; count <= 10; count++) {
        for (var index = 0; index < 10; index++) {
          final next = KecrekanMath.toggledCount(count, index);
          expect(next, inInclusiveRange(0, 10));
          expect((next - count).abs(), 1);
        }
      }
    });
  });

  group('drag', () {
    test('a still finger changes nothing', () {
      expect(KecrekanMath.dragCount(startCount: 4, dx: 0), 4);
      expect(KecrekanMath.dragCount(startCount: 4, dx: 0.04), 4);
      expect(KecrekanMath.dragCount(startCount: 4, dx: -0.04), 4);
    });

    test('dragging left counts beads, dragging right sends them back', () {
      final spacing = KecrekanMath.spacing;
      expect(KecrekanMath.dragCount(startCount: 0, dx: -spacing), 1);
      expect(KecrekanMath.dragCount(startCount: 0, dx: -3 * spacing), 3);
      expect(KecrekanMath.dragCount(startCount: 6, dx: spacing), 5);
      expect(KecrekanMath.dragCount(startCount: 6, dx: 2 * spacing), 4);
    });

    test('reversing retraces the same counts without lifting', () {
      final spacing = KecrekanMath.spacing;
      const start = 0;
      const forward = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final backward = [...forward.reversed, 0, -1, -2];
      for (final slots in [...forward, ...backward]) {
        final next = KecrekanMath.dragCount(
          startCount: start,
          dx: -slots * spacing,
        );
        // Every frame is computed from the anchor, so reversing retraces the
        // identical counts with no accumulated drift or skipped values.
        expect(next, slots.clamp(0, 10));
      }
    });

    test('one step per slot, never a jump', () {
      final spacing = KecrekanMath.spacing;
      var previous = 0;
      for (var step = 0; step <= 20; step++) {
        final next = KecrekanMath.dragCount(
          startCount: 0,
          dx: -step * spacing / 2,
        );
        if (next != previous) {
          expect((next - previous).abs(), 1);
        }
        previous = next;
      }
      expect(previous, 10);
    });

    test('hysteresis stops flicker at a threshold', () {
      final spacing = KecrekanMath.spacing;
      // Half a slot alone is not enough; it needs the dead band too.
      expect(KecrekanMath.dragCount(startCount: 2, dx: -0.5 * spacing), 2);
      expect(
        KecrekanMath.dragCount(startCount: 2, dx: -(0.5 + 0.13) * spacing),
        3,
      );
      // Coming back to exactly the half-way point does not reverse.
      expect(KecrekanMath.dragCount(startCount: 3, dx: -0.5 * spacing), 3);
    });

    test('clamps at the ends of the rod', () {
      final spacing = KecrekanMath.spacing;
      expect(KecrekanMath.dragCount(startCount: 0, dx: 40 * spacing), 0);
      expect(KecrekanMath.dragCount(startCount: 10, dx: -40 * spacing), 10);
    });

    test('final bead positions always match the logical count', () {
      for (var count = 0; count <= 10; count++) {
        final positions = [
          for (var i = 0; i < 10; i++) KecrekanMath.beadX(i, count),
        ];
        expect(positions.toSet().length, 10, reason: 'no two beads overlap');

        // The counted run packs against the left stop and the uncounted run
        // against the right, each one contiguous and in bead order.
        final counted = <double>[];
        final uncounted = <double>[];
        for (var i = 0; i < 10; i++) {
          final expected = i >= 10 - count
              ? KecrekanMath.leftX + (9 - i) * KecrekanMath.spacing
              : KecrekanMath.rightX - i * KecrekanMath.spacing;
          expect(positions[i], closeTo(expected, 1e-9));
          (i >= 10 - count ? counted : uncounted).add(positions[i]);
        }
        expect(counted.length, count);
        expect(uncounted.length, 10 - count);
        if (counted.isNotEmpty && uncounted.isNotEmpty) {
          expect(
            counted.reduce((a, b) => a > b ? a : b),
            lessThan(uncounted.reduce((a, b) => a < b ? a : b)),
            reason: 'the two runs never interleave or overlap',
          );
        }
      }
    });
  });
}
