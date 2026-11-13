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

    test('the five split leaves the half-bead gap', () {
      final positions = [
        for (var i = 0; i < 10; i++) KecrekanMath.beadX(i, 5),
      ];
      final gap = positions[4] - positions[5];
      expect(gap, closeTo(0.72, 0.0001));
      expect(positions.first, KecrekanMath.rightX);
      expect(positions.last, KecrekanMath.leftX);
    });

    test('counted beads pack to the left and uncounted to the right', () {
      expect(KecrekanMath.beadX(9, 0), KecrekanMath.rightX - 9 * KecrekanMath.spacing);
      expect(KecrekanMath.beadX(9, 10), KecrekanMath.leftX);
      expect(KecrekanMath.beadX(0, 10), KecrekanMath.leftX + 9 * KecrekanMath.spacing);
    });

    test('edge helpers point at the bead next to the gap', () {
      expect(KecrekanMath.nextUncountedIndex(0), 9);
      expect(KecrekanMath.nextUncountedIndex(10), -1);
      expect(KecrekanMath.edgeCountedIndex(0), -1);
      expect(KecrekanMath.edgeCountedIndex(5), 5);
    });
  });
}
