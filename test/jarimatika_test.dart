import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/jarimatika/hand_painter.dart';

void main() {
  test('the canonical Jarimatika shapes are exact', () {
    expect(kJarimatikaShapes[1], {Finger.indexFinger});
    expect(kJarimatikaShapes[2], {Finger.indexFinger, Finger.middle});
    expect(kJarimatikaShapes[3],
        {Finger.indexFinger, Finger.middle, Finger.ring});
    expect(kJarimatikaShapes[4],
        {Finger.indexFinger, Finger.middle, Finger.ring, Finger.pinky});
    expect(kJarimatikaShapes[5], {Finger.thumb});
    expect(kJarimatikaShapes[6], {Finger.thumb, Finger.indexFinger});
    expect(kJarimatikaShapes[7],
        {Finger.thumb, Finger.indexFinger, Finger.middle});
    expect(kJarimatikaShapes[8],
        {Finger.thumb, Finger.indexFinger, Finger.middle, Finger.ring});
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
}
