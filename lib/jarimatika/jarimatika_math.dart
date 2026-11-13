import 'dart:math' as math;
import 'dart:ui' show Offset;

/// One of the five digits of a hand.
enum Finger { thumb, indexFinger, middle, ring, pinky }

const List<Finger> kFingerOrder = [
  Finger.thumb,
  Finger.indexFinger,
  Finger.middle,
  Finger.ring,
  Finger.pinky,
];

/// The canonical Jarimatika shapes for one hand.
///
/// Right hand counts ones. 1 index, 2 index+middle, 3 plus ring, 4 plus
/// pinky, 5 thumb, 6 thumb+index, 7 plus middle, 8 plus ring, 9 all five.
/// The left hand is the same shape times ten.
const Map<int, Set<Finger>> kJarimatikaShapes = {
  0: <Finger>{},
  1: {Finger.indexFinger},
  2: {Finger.indexFinger, Finger.middle},
  3: {Finger.indexFinger, Finger.middle, Finger.ring},
  4: {Finger.indexFinger, Finger.middle, Finger.ring, Finger.pinky},
  5: {Finger.thumb},
  6: {Finger.thumb, Finger.indexFinger},
  7: {Finger.thumb, Finger.indexFinger, Finger.middle},
  8: {Finger.thumb, Finger.indexFinger, Finger.middle, Finger.ring},
  9: {
    Finger.thumb,
    Finger.indexFinger,
    Finger.middle,
    Finger.ring,
    Finger.pinky,
  },
};

/// Fold angles in radians about each bone's local X axis.
///
/// These mirror the pose authored in `tools/blender/build_hand.py`: positive
/// extension drives every angle toward zero, so a fully extended finger is
/// straight and a folded one curls toward the palm.
const Map<Finger, List<double>> kFingerFolds = {
  Finger.thumb: [-0.82, -0.42, -0.28, -0.16],
  Finger.indexFinger: [-0.86, -0.98, -0.42],
  Finger.middle: [-0.82, -1.02, -0.46],
  Finger.ring: [-0.88, -1.00, -0.44],
  Finger.pinky: [-0.94, -1.02, -0.48],
};

/// The bone key used by the glTF skeleton for a finger.
String fingerBoneKey(Finger finger) => switch (finger) {
  Finger.thumb => 'thumb',
  Finger.indexFinger => 'index',
  Finger.middle => 'middle',
  Finger.ring => 'ring',
  Finger.pinky => 'pinky',
};

/// Every bone node that carries a finger, ordered from knuckle to tip.
List<String> fingerBoneNames(Finger finger) {
  final key = fingerBoneKey(finger);
  if (finger == Finger.thumb) {
    return [for (var i = 1; i <= 4; i++) 'thumb_0$i'];
  }
  return [for (var i = 1; i <= 3; i++) '${key}_0$i'];
}

/// The terminal bone node, used as the final point when hit testing.
String fingerTipName(Finger finger) => '${fingerBoneKey(finger)}_tip';

/// The digit a set of extended fingers represents, or null for a shape that is
/// not part of the Jarimatika set.
int? handValue(Set<Finger> fingers) {
  for (final entry in kJarimatikaShapes.entries) {
    if (entry.value.length == fingers.length &&
        entry.value.containsAll(fingers)) {
      return entry.key;
    }
  }
  return null;
}

Set<Finger> fingersFor(int digit) =>
    Set<Finger>.from(kJarimatikaShapes[digit.clamp(0, 9)] ?? const {});

String fingerName(Finger finger) => switch (finger) {
  Finger.thumb => 'Thumb',
  Finger.indexFinger => 'Index',
  Finger.middle => 'Middle',
  Finger.ring => 'Ring',
  Finger.pinky => 'Pinky',
};

/// Joint angles for a finger at a given extension (0 folded, 1 straight).
List<double> poseAngles(Finger finger, double extension) {
  final e = extension.clamp(0.0, 1.0);
  return [for (final fold in kFingerFolds[finger]!) fold * (1.0 - e)];
}

/// Distance from [p] to the segment a–b.
double distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared == 0) return (p - a).distance;
  var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Picks the finger whose projected skeleton is nearest [position].
///
/// [projected] maps each finger to its joints in screen space, ordered from
/// the knuckle outward. The result is null when nothing is within
/// [maxDistance], so a tap on the palm does not toggle a finger.
Finger? hitTestFinger({
  required Offset position,
  required Map<Finger, List<Offset>> projected,
  double maxDistance = 30,
}) {
  Finger? best;
  var bestDistance = double.infinity;
  for (final entry in projected.entries) {
    final points = entry.value;
    for (var i = 0; i < points.length - 1; i++) {
      final distance = distanceToSegment(position, points[i], points[i + 1]);
      // Bias toward the distal joints: when fingers overlap near the knuckle,
      // the fingertip is what the child is aiming at.
      final score = distance * (i == points.length - 2 ? 0.92 : 1.0);
      if (score < bestDistance) {
        bestDistance = score;
        best = entry.key;
      }
    }
  }
  return bestDistance <= maxDistance ? best : null;
}

/// A forgiving hit radius for a hand of [widgetSize] logical pixels.
double fingerHitRadius(double widgetSize) => math.max(24.0, widgetSize * 0.135);
