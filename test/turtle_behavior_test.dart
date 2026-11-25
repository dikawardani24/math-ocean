import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/turtle/turtle_behavior.dart';

const _step = 1 / 30;

void _advance(TurtleBehaviorController controller, double seconds) {
  final steps = (seconds / _step).ceil();
  for (var i = 0; i < steps; i++) {
    controller.update(_step);
  }
}

void main() {
  test('autonomous exploration selects destinations inside the bounds', () {
    final controller = TurtleBehaviorController(
      autonomy: TurtleAutonomy.free,
      random: math.Random(7),
    );

    var travelled = false;
    var deepest = 0.0;
    for (var frame = 0; frame < 30 * 60; frame++) {
      controller.update(_step);
      final position = controller.position;
      expect(controller.bounds.contains(position), isTrue);
      expect(controller.pose.depth, inInclusiveRange(-1, 1));
      deepest = math.max(deepest, controller.pose.depth.abs());
      if (controller.activity == TurtleActivity.turning ||
          controller.activity == TurtleActivity.swimming) {
        travelled = true;
      }
    }

    expect(travelled, isTrue);
    expect(deepest, greaterThan(.05));
    expect(controller.bounds.contains(controller.position), isTrue);
  });

  test('turning is gradual and movement follows the current heading', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .5),
      initialHeading: 0,
      autonomy: TurtleAutonomy.calm,
      random: math.Random(1),
    );

    expect(controller.requestFeed(const Offset(.1, .5)), isTrue);
    controller.update(.05);

    // A 180-degree target must not snap. One update may only apply the capped
    // angular step, and the turtle must not translate sideways to the target.
    expect(controller.heading, lessThan(0));
    expect(controller.heading.abs(), lessThan(.2));
    expect(controller.position.dx, greaterThan(.49));

    _advance(controller, 2.5);
    expect(controller.heading.abs(), greaterThan(2.4));
    expect(controller.position.dx, lessThan(.45));
  });

  test('feeding waits for physical arrival, then locks in place', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .5),
      autonomy: TurtleAutonomy.calm,
      random: math.Random(3),
    );

    expect(controller.requestFeed(const Offset(.72, .5)), isTrue);

    var arrived = false;
    for (var i = 0; i < 30 * 12 && !arrived; i++) {
      controller.update(_step);
      arrived = controller.takeFeedArrived();
    }

    expect(arrived, isTrue);
    expect(controller.activity, TurtleActivity.feeding);
    expect(
      (controller.position - const Offset(.72, .5)).distance,
      lessThan(.09),
    );

    final fedAt = controller.position;
    _advance(controller, 2);
    expect((controller.position - fedAt).distance, lessThan(.001));
    expect(controller.activity, TurtleActivity.feeding);

    // A tap cannot corrupt the feeding state.
    expect(controller.reactToPlayer(), isFalse);
    expect(controller.activity, TurtleActivity.feeding);

    controller.finishFeeding();
    expect(controller.activity, TurtleActivity.happy);
    _advance(controller, 2.2);
    expect(controller.activity, isNot(TurtleActivity.feeding));
    expect(controller.activity, isNot(TurtleActivity.happy));
  });

  test('player reaction cancels travel and respects its cooldown', () {
    final controller = TurtleBehaviorController(
      autonomy: TurtleAutonomy.free,
      random: math.Random(5),
    );

    // Let the autonomous cycle pick a destination.
    for (var i = 0; i < 30 * 8 && controller.target == null; i++) {
      controller.update(_step);
    }
    expect(controller.target, isNotNull);

    expect(controller.reactToPlayer(from: const Offset(.1, .15)), isTrue);
    expect(controller.activity, TurtleActivity.reacting);
    expect(controller.target, isNull);

    final reactedAt = controller.position;
    _advance(controller, .3);
    expect((controller.position - reactedAt).distance, lessThan(.01));
    expect(controller.reactToPlayer(), isFalse);

    _advance(controller, 1.2);
    expect(controller.activity, TurtleActivity.idle);
  });

  test('calm autonomy cancels a trip and then stays settled', () {
    final controller = TurtleBehaviorController(
      autonomy: TurtleAutonomy.free,
      random: math.Random(9),
    );

    for (var i = 0; i < 30 * 8 && controller.target == null; i++) {
      controller.update(_step);
    }
    expect(controller.target, isNotNull);

    controller.setAutonomy(TurtleAutonomy.calm);
    expect(controller.target, isNull);
    expect(
      const {
        TurtleActivity.exploring,
        TurtleActivity.turning,
        TurtleActivity.swimming,
        TurtleActivity.approachingTarget,
      }.contains(controller.activity),
      isFalse,
    );

    _advance(controller, 1.2);
    final settledAt = controller.position;
    _advance(controller, 2.5);
    expect((controller.position - settledAt).distance, lessThan(.01));
  });

  test('a feed target outside the swim area is clamped and reachable', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .5),
      autonomy: TurtleAutonomy.calm,
      random: math.Random(11),
    );

    expect(controller.requestFeed(const Offset(-3, 4)), isTrue);
    final target = controller.target;
    expect(target, isNotNull);
    expect(controller.bounds.contains(target!), isTrue);

    var arrived = false;
    for (var i = 0; i < 30 * 12 && !arrived; i++) {
      controller.update(_step);
      expect(controller.bounds.contains(controller.position), isTrue);
      arrived = controller.takeFeedArrived();
    }
    expect(arrived, isTrue);
  });

  test('resting stops movement and relaxes the paddle', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .7),
      autonomy: TurtleAutonomy.rest,
      random: math.Random(13),
    );

    _advance(controller, .2);
    expect(controller.activity, TurtleActivity.resting);
    final restAt = controller.position;
    _advance(controller, 2.5);

    expect((controller.position - restAt).distance, lessThan(.001));
    expect(controller.pose.paddle, 0);
  });

  test('visual yaw follows horizontal travel direction', () {
    final rightward = TurtleBehaviorController(
      initialPosition: const Offset(.2, .5),
      initialHeading: 0,
      autonomy: TurtleAutonomy.calm,
      random: math.Random(17),
    );
    rightward.requestFeed(const Offset(.9, .5));
    _advance(rightward, 1.5);
    expect(rightward.pose.yaw, greaterThan(.1));

    final leftward = TurtleBehaviorController(
      initialPosition: const Offset(.8, .5),
      initialHeading: math.pi,
      autonomy: TurtleAutonomy.calm,
      random: math.Random(19),
    );
    leftward.requestFeed(const Offset(.1, .5));
    _advance(leftward, 1.5);
    expect(leftward.pose.yaw, lessThan(-.1));
  });

  test('pitch follows vertical travel and turns stay readable', () {
    final rising = TurtleBehaviorController(
      initialPosition: const Offset(.5, .8),
      initialHeading: -math.pi / 2,
      autonomy: TurtleAutonomy.calm,
      random: math.Random(31),
    );
    rising.requestFeed(const Offset(.5, .1));
    _advance(rising, 1.5);
    expect(rising.pose.pitch, greaterThan(.1));

    final diving = TurtleBehaviorController(
      initialPosition: const Offset(.5, .2),
      initialHeading: math.pi / 2,
      autonomy: TurtleAutonomy.calm,
      random: math.Random(37),
    );
    diving.requestFeed(const Offset(.5, .9));
    _advance(diving, 1.5);
    expect(diving.pose.pitch, lessThan(-.1));

    // Never a full side profile: the face stays visible to the child.
    for (var i = 0; i < 30 * 20; i++) {
      rising.update(_step);
      expect(rising.pose.yaw.abs(), lessThanOrEqualTo(.63));
      expect(rising.pose.pitch.abs(), lessThanOrEqualTo(.33));
    }
  });

  test('depth is real and eases to the feeding plane', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .5),
      autonomy: TurtleAutonomy.calm,
      random: math.Random(41),
    );

    controller.requestFeed(const Offset(.55, .46));
    var arrived = false;
    for (var i = 0; i < 30 * 12 && !arrived; i++) {
      controller.update(_step);
      expect(controller.pose.depth, inInclusiveRange(-1, 1));
      arrived = controller.takeFeedArrived();
    }
    expect(arrived, isTrue);
    _advance(controller, 2);
    expect(controller.pose.depth.abs(), lessThan(.02));
  });

  test('a very long frame is clamped to a safe movement step', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .5),
      autonomy: TurtleAutonomy.calm,
      random: math.Random(23),
    );
    controller.requestFeed(const Offset(.9, .5));
    controller.update(5);

    expect(
      (controller.position - const Offset(.5, .5)).distance,
      lessThan(.03),
    );
  });

  test('feeding completes without autonomous drift afterwards', () {
    final controller = TurtleBehaviorController(
      initialPosition: const Offset(.5, .5),
      autonomy: TurtleAutonomy.free,
      random: math.Random(29),
    );

    controller.requestFeed(const Offset(.55, .48));
    var arrived = false;
    for (var i = 0; i < 30 * 8 && !arrived; i++) {
      controller.update(_step);
      arrived = controller.takeFeedArrived();
    }
    expect(arrived, isTrue);
    controller.finishFeeding();

    _advance(controller, 2.2);
    final afterReaction = controller.position;
    _advance(controller, 2);
    // Free mode may pick a new destination, but it must start from the same
    // place rather than teleporting when the meal ends.
    expect((controller.position - afterReaction).distance, lessThan(.2));
  });
}
