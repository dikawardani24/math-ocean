import 'turtle_behavior.dart';

/// Which imported clip (if any) should accompany a behaviour.
///
/// The current `tala_sea_turtle.glb` is a static single mesh with no clips, so
/// the renderer resolves these names against the clips the model actually
/// contains. It stays silent when a clip is absent and the procedural body
/// motion carries the performance instead. This mapping is ready for a future
/// rigged model that provides the documented names.
class TurtleAnimationCue {
  const TurtleAnimationCue({
    required this.clip,
    this.loop = true,
    this.speed = 1,
  });

  final String? clip;
  final bool loop;
  final double speed;

  /// Cheap comparison key. Speed is quantised so tiny per-frame changes do not
  /// rebuild the scene widget.
  int get signature => Object.hash(clip, loop, (speed * 10).round());
}

TurtleAnimationCue turtleAnimationCueFor(
  TurtleActivity activity,
  double speedRatio,
) {
  switch (activity) {
    case TurtleActivity.feeding:
      return const TurtleAnimationCue(clip: 'Eat_Chew', loop: false, speed: 1);
    case TurtleActivity.happy:
    case TurtleActivity.reacting:
      return const TurtleAnimationCue(
        clip: 'Happy_Reaction',
        loop: false,
        speed: 1,
      );
    case TurtleActivity.resting:
      return const TurtleAnimationCue(clip: 'Idle_Swim', speed: .35);
    case TurtleActivity.turning:
      return const TurtleAnimationCue(clip: 'Idle_Swim', speed: .55);
    case TurtleActivity.idle:
      return const TurtleAnimationCue(clip: 'Idle_Swim', speed: .45);
    case TurtleActivity.exploring:
    case TurtleActivity.swimming:
    case TurtleActivity.approachingTarget:
      return TurtleAnimationCue(
        clip: 'Idle_Swim',
        speed: .65 + .8 * speedRatio.clamp(0.0, 1.0),
      );
  }
}
