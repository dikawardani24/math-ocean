import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/kecrekan/kecrekan_math.dart';

void main() {
  group('KecrekanMath', () {
    test('starts empty and counts up to twenty-five', () {
      final math = KecrekanMath();
      expect(math.total, 0);
      math.setTotal(25);
      expect(math.total, 25);
      expect(math.rodCounts.every((c) => c == 5), isTrue);
    });

    test('fills rows from the top', () {
      final math = KecrekanMath();
      math.setTotal(13);
      expect(math.rodCounts.take(4), [5, 5, 3, 0]);
      expect(math.total, 13);
    });

    test('clamps a row to five beads', () {
      final math = KecrekanMath();
      math.setCount(0, 99);
      expect(math.countFor(0), 5);
      math.add(0, -50);
      expect(math.countFor(0), 0);
    });

    test('bead order never swaps', () {
      for (var count = 0; count <= 5; count++) {
        final positions = [
          for (var i = 0; i < 5; i++) KecrekanMath.beadX(i, count),
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

    test('the five beads form one complete row', () {
      final positions = [for (var i = 0; i < 5; i++) KecrekanMath.beadX(i, 2)];
      final gap = positions[2] - positions[3];
      // One empty slot between the groups; the bead that crosses it moves by
      // one spacing, not by the old two-and-a-bit spacing hole.
      expect(gap, closeTo(2 * KecrekanMath.spacing, 0.0001));
      expect(gap, closeTo(2 * KecrekanMath.spacing, 0.0001));
      expect(positions.first, KecrekanMath.rightX);
      expect(positions.last, KecrekanMath.leftX + KecrekanMath.spacing);
    });

    test('one count moves the crossing bead exactly one slot', () {
      for (var count = 0; count < 5; count++) {
        final crossing = 4 - count;
        final before = KecrekanMath.beadX(crossing, count);
        final after = KecrekanMath.beadX(crossing, count + 1);
        expect(
          before - after,
          closeTo(KecrekanMath.spacing, 1e-9),
          reason: 'count $count -> ${count + 1} should move one slot only',
        );
      }
    });

    test('the five slots fill the packing span exactly', () {
      expect(
        KecrekanMath.rightX - KecrekanMath.leftX,
        closeTo(5 * KecrekanMath.spacing, 1e-9),
      );
      // At rest the left-most uncounted bead sits exactly one slot from the
      // left stop, so the first drag has somewhere to go.
      expect(
        KecrekanMath.beadX(4, 0),
        closeTo(KecrekanMath.leftX + KecrekanMath.spacing, 1e-9),
      );
    });

    test('counted beads pack to the left and uncounted to the right', () {
      expect(
        KecrekanMath.beadX(4, 0),
        KecrekanMath.rightX - 4 * KecrekanMath.spacing,
      );
      expect(KecrekanMath.beadX(4, 5), KecrekanMath.leftX);
      expect(
        KecrekanMath.beadX(0, 5),
        KecrekanMath.leftX + 4 * KecrekanMath.spacing,
      );
    });

    test('edge helpers point at the bead next to the gap', () {
      expect(KecrekanMath.nextUncountedIndex(0), 4);
      expect(KecrekanMath.nextUncountedIndex(5), -1);
      expect(KecrekanMath.edgeCountedIndex(0), -1);
      expect(KecrekanMath.edgeCountedIndex(5), 0);
    });
  });

  group('tap', () {
    test('moves exactly one bead in the expected direction', () {
      // Uncounted bead joins the counted group.
      expect(KecrekanMath.toggledCount(0, 4), 1);
      expect(KecrekanMath.toggledCount(4, 0), 5);
      // Counted bead goes back.
      expect(KecrekanMath.toggledCount(5, 0), 4);
      expect(KecrekanMath.toggledCount(5, 4), 4);
    });

    test('never leaves the rod range', () {
      expect(KecrekanMath.toggledCount(10, 9), 9);
      expect(KecrekanMath.toggledCount(0, 0), 1);
      for (var count = 0; count <= 5; count++) {
        for (var index = 0; index < 5; index++) {
          final next = KecrekanMath.toggledCount(count, index);
          expect(next, inInclusiveRange(0, 5));
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
      const forward = [1, 2, 3, 4, 5];
      final backward = [...forward.reversed, 0, -1, -2];
      for (final slots in [...forward, ...backward]) {
        final next = KecrekanMath.dragCount(
          startCount: start,
          dx: -slots * spacing,
        );
        // Every frame is computed from the anchor, so reversing retraces the
        // identical counts with no accumulated drift or skipped values.
        expect(next, slots.clamp(0, 5));
      }
    });

    test('one step per slot, never a jump', () {
      final spacing = KecrekanMath.spacing;
      var previous = 0;
      for (var step = 0; step <= 10; step++) {
        final next = KecrekanMath.dragCount(
          startCount: 0,
          dx: -step * spacing / 2,
        );
        if (next != previous) {
          expect((next - previous).abs(), 1);
        }
        previous = next;
      }
      expect(previous, 5);
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
      expect(KecrekanMath.dragCount(startCount: 5, dx: -40 * spacing), 5);
    });

    test('final bead positions always match the logical count', () {
      for (var count = 0; count <= 5; count++) {
        final positions = [
          for (var i = 0; i < 5; i++) KecrekanMath.beadX(i, count),
        ];
        expect(positions.toSet().length, 5, reason: 'no two beads overlap');

        // The counted run packs against the left stop and the uncounted run
        // against the right, each one contiguous and in bead order.
        final counted = <double>[];
        final uncounted = <double>[];
        for (var i = 0; i < 5; i++) {
          final expected = i >= 5 - count
              ? KecrekanMath.leftX + (4 - i) * KecrekanMath.spacing
               : KecrekanMath.rightX - i * KecrekanMath.spacing;
          expect(positions[i], closeTo(expected, 1e-9));
          (i >= 5 - count ? counted : uncounted).add(positions[i]);
        }
        expect(counted.length, count);
        expect(uncounted.length, 5 - count);
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
