import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/jarimatika/hand_painter.dart';

void main() {
  test('the canonical Jarimatika shapes are exact', () {
    expect(kJarimatikaShapes[1], {Finger.indexFinger});
    expect(kJarimatikaShapes[2], {Finger.indexFinger, Finger.middle});
    expect(kJarimatikaShapes[3], {
      Finger.indexFinger,
      Finger.middle,
      Finger.ring,
    });
    expect(kJarimatikaShapes[4], {
      Finger.indexFinger,
      Finger.middle,
      Finger.ring,
      Finger.pinky,
    });
    expect(kJarimatikaShapes[5], {Finger.thumb});
    expect(kJarimatikaShapes[6], {Finger.thumb, Finger.indexFinger});
    expect(kJarimatikaShapes[7], {
      Finger.thumb,
      Finger.indexFinger,
      Finger.middle,
    });
    expect(kJarimatikaShapes[8], {
      Finger.thumb,
      Finger.indexFinger,
      Finger.middle,
      Finger.ring,
    });
    expect(kJarimatikaShapes[9], kJarimatikaShapes[9]!.toSet());
    expect(kJarimatikaShapes[9]!.length, 5);
  });

  test('handValue round-trips every digit', () {
    for (var digit = 0; digit <= 9; digit++) {
      expect(handValue(fingersFor(digit)), digit);
    }
  });

  test('an arbitrary shape is not a Jarimatika number', () {
    expect(handValue({Finger.middle, Finger.pinky}), isNull);
    expect(handValue({Finger.indexFinger, Finger.pinky}), isNull);
  });

  test('fingersFor clamps out of range input', () {
    expect(fingersFor(12), fingersFor(9));
    expect(fingersFor(-2), isEmpty);
  });

  group('pose angles', () {
    test('a fully extended finger is straight', () {
      for (final finger in kFingerOrder) {
        expect(poseAngles(finger, 1), everyElement(closeTo(0, 1e-12)));
      }
    });

    test('a folded finger matches its authored fold', () {
      for (final finger in kFingerOrder) {
        expect(poseAngles(finger, 0), kFingerFolds[finger]);
      }
    });

    test('partial extension interpolates and clamps', () {
      final half = poseAngles(Finger.indexFinger, 0.5);
      final fold = kFingerFolds[Finger.indexFinger]!;
      for (var i = 0; i < fold.length; i++) {
        expect(half[i], closeTo(fold[i] * 0.5, 1e-12));
      }
      // Out-of-range input cannot over-extend or over-fold the rig.
      expect(poseAngles(Finger.pinky, 2), poseAngles(Finger.pinky, 1));
      expect(poseAngles(Finger.pinky, -1), poseAngles(Finger.pinky, 0));
    });

    test('every bone named for a finger exists in its fold list', () {
      for (final finger in kFingerOrder) {
        expect(
          fingerBoneNames(finger),
          hasLength(kFingerFolds[finger]!.length),
        );
        expect(fingerBoneNames(finger).first, endsWith('_01'));
        expect(fingerTipName(finger), endsWith('_tip'));
      }
      expect(fingerBoneNames(Finger.thumb), [
        'thumb_01',
        'thumb_02',
        'thumb_03',
        'thumb_04',
      ]);
      expect(fingerBoneNames(Finger.middle), [
        'middle_01',
        'middle_02',
        'middle_03',
      ]);
    });
  });

  group('projected hit testing', () {
    const index = Finger.indexFinger;
    const middle = Finger.middle;

    Map<Finger, List<Offset>> twoFingers() => {
      index: const [Offset(100, 300), Offset(100, 200), Offset(100, 120)],
      middle: const [Offset(150, 300), Offset(150, 200), Offset(150, 120)],
    };

    test('picks the nearest projected finger', () {
      expect(
        hitTestFinger(
          position: const Offset(108, 240),
          projected: twoFingers(),
        ),
        index,
      );
      expect(
        hitTestFinger(
          position: const Offset(143, 240),
          projected: twoFingers(),
        ),
        middle,
      );
    });

    test('a tap between fingers still resolves to one', () {
      final finger = hitTestFinger(
        position: const Offset(125, 220),
        projected: twoFingers(),
      );
      expect(finger, isNotNull);
      expect({index, middle}, contains(finger));
    });

    test('ignores taps away from every finger', () {
      expect(
        hitTestFinger(
          position: const Offset(125, 420),
          projected: twoFingers(),
        ),
        isNull,
      );
      expect(
        hitTestFinger(position: const Offset(60, 240), projected: twoFingers()),
        isNull,
      );
    });

    test('the forgiving radius grows with the widget and has a floor', () {
      expect(fingerHitRadius(160), 24);
      expect(fingerHitRadius(240), closeTo(32.4, 0.01));
      expect(fingerHitRadius(600), 81);
      // A tap just inside the radius wins; just outside does not.
      final radius = fingerHitRadius(240);
      final lone = {
        index: const [Offset(100, 300), Offset(100, 200), Offset(100, 100)],
      };
      expect(
        hitTestFinger(
          position: Offset(100 + radius - 1, 300),
          projected: lone,
          maxDistance: radius,
        ),
        index,
      );
      expect(
        hitTestFinger(
          position: Offset(100 + radius + 1, 300),
          projected: lone,
          maxDistance: radius,
        ),
        isNull,
      );
    });

    test('distanceToSegment clamps to the endpoints', () {
      expect(
        distanceToSegment(
          const Offset(-3, 4),
          Offset.zero,
          const Offset(10, 0),
        ),
        5,
      );
      expect(
        distanceToSegment(
          const Offset(5, -2),
          Offset.zero,
          const Offset(10, 0),
        ),
        2,
      );
    });
  });
}
