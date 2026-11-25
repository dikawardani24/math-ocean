import 'dart:math' as math;
import 'dart:ui' show Offset;

/// What Tala is doing right now.
enum TurtleActivity {
  idle,
  swimming,
  turning,
  exploring,
  approachingTarget,
  feeding,
  resting,
  reacting,
  happy,
}

/// How much freedom the current gameplay phase gives Tala.
enum TurtleAutonomy {
  /// Explore the swim area, then stop and observe.
  free,

  /// Stay still and calm. Used while the child is counting or collecting.
  calm,

  /// Settle down and stay resting.
  rest,
}

enum _TargetPurpose { none, explore, rest, feed }

/// Normalized bounds for the turtle's centre inside its swim area.
///
/// Keeping movement normalized means the behavior is independent of screen
/// size and can be unit tested without a render tree.
class TurtleBounds {
  const TurtleBounds({
    this.minX = .04,
    this.maxX = .96,
    this.minY = .06,
    this.maxY = .94,
  }) : assert(minX < maxX),
       assert(minY < maxY);

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;

  bool contains(Offset point) =>
      point.dx >= minX &&
      point.dx <= maxX &&
      point.dy >= minY &&
      point.dy <= maxY;

  Offset clamp(Offset point) => Offset(
    point.dx.clamp(minX, maxX).toDouble(),
    point.dy.clamp(minY, maxY).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is TurtleBounds &&
      other.minX == minX &&
      other.maxX == maxX &&
      other.minY == minY &&
      other.maxY == maxY;

  @override
  int get hashCode => Object.hash(minX, maxX, minY, maxY);
}

/// Immutable snapshot consumed by the renderer.
class TurtlePose {
  const TurtlePose({
    required this.position,
    required this.heading,
    required this.speed,
    required this.speedRatio,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.bob,
    required this.paddle,
    required this.depth,
    required this.scale,
    required this.activity,
  });

  /// Normalized centre inside the swim bounds.
  final Offset position;

  /// Direction of travel in screen space. Zero points right.
  final double heading;

  /// Current forward speed in normalized bounds per second.
  final double speed;

  /// Speed as a fraction of the controller's cruise speed.
  final double speedRatio;

  /// Visual yaw/pitch/roll derived from heading, turning and behaviour.
  final double yaw;
  final double pitch;
  final double roll;

  /// Small vertical breathing/celebration offset as a fraction of the turtle's
  /// own height. The renderer turns this into world units.
  final double bob;

  /// Paddle rhythm in [-1, 1]. Zero while resting.
  final double paddle;

  /// Depth inside the swim volume: `-1` is far from the camera, `0` is the
  /// resting plane, `1` is near. This is real 3D depth, not a size fudge.
  final double depth;

  /// Celebration squash/stretch around one. The renderer multiplies it with
  /// the world scale, so it is not a perspective substitute.
  final double scale;

  final TurtleActivity activity;
}

/// Lightweight, render-independent turtle brain.
///
/// It owns exactly one moving point and a heading. There is no physics engine,
/// no scene query and no per-frame allocation beyond the small [TurtlePose]
/// snapshot. The widget supplies delta time and maps the pose to the 3D view.
class TurtleBehaviorController {
  TurtleBehaviorController({
    TurtleBounds bounds = const TurtleBounds(),
    this._autonomy = TurtleAutonomy.free,
    Offset initialPosition = const Offset(.5, .5),
    double initialHeading = math.pi / 2,
    math.Random? random,
  }) : _bounds = bounds,
       _random = random ?? math.Random(),
       _position = bounds.clamp(initialPosition),
       _heading = _wrapAngle(initialHeading) {
    if (_autonomy == TurtleAutonomy.rest) {
      _enterRest();
    } else {
      _enterIdle();
    }
  }

  static const double maxSpeed = .20;
  static const double acceleration = .55;
  static const double deceleration = .62;
  static const double turnRate = 2.6;
  static const double turnThreshold = .55;
  static const double arriveDistance = .035;
  static const double slowRadius = .22;
  static const double happyDuration = 1.9;
  static const double reactionDuration = .95;
  static const double _turnDriftSpeed = .012;

  final math.Random _random;

  TurtleBounds _bounds;
  TurtleAutonomy _autonomy;
  Offset _position;
  double _heading;
  double _speed = 0;
  double _lastTurnRate = 0;

  TurtleActivity _activity = TurtleActivity.idle;
  Offset? _target;
  _TargetPurpose _targetPurpose = _TargetPurpose.none;
  double _timeLeft = 0;
  double _stateElapsed = 0;

  double _feedArriveDistance = .05;
  bool _feedArrivedEvent = false;
  double _feedNodTime = 0;

  double _reactionCooldown = 0;
  double? _reactionHeading;

  double _lookOffset = 0;
  double _lookTarget = 0;
  double _lookTimer = 0;

  double _paddlePhase = 0;
  double _breathPhase = 0;
  double _depth = 0;
  double _depthTarget = 0;

  TurtleActivity get activity => _activity;
  Offset get position => _position;
  double get heading => _heading;
  double get speed => _speed;
  double get speedRatio => (_speed / maxSpeed).clamp(0, 1);
  Offset? get target => _target;
  double get depth => _depth;
  TurtleAutonomy get autonomy => _autonomy;
  TurtleBounds get bounds => _bounds;
  bool get isFeeding => _activity == TurtleActivity.feeding;
  double get reactionCooldown => _reactionCooldown;

  /// One-shot event consumed by the renderer, which forwards it to gameplay.
  bool takeFeedArrived() {
    final arrived = _feedArrivedEvent;
    _feedArrivedEvent = false;
    return arrived;
  }

  void update(double deltaSeconds) {
    if (deltaSeconds <= 0) return;
    final dt = math.min(deltaSeconds, .1);

    _stateElapsed += dt;
    _reactionCooldown = math.max(0, _reactionCooldown - dt);
    _feedNodTime = math.max(0, _feedNodTime - dt);
    _paddlePhase += dt * (2.2 + 11 * speedRatio);
    _breathPhase += dt * 1.05;
    // Ease through depth rather than jumping planes. A ~1.4s time constant
    // keeps the approach to food readable and the idle drift calm; feeding
    // settles onto the food plane faster so the bite stays at the mouth.
    final depthRate = _activity == TurtleActivity.feeding ? 3.0 : .72;
    _depth += (_depthTarget - _depth) * math.min(1, dt * depthRate);

    switch (_activity) {
      case TurtleActivity.idle:
        _decelerate(dt);
        _updateLook(dt, calm: true);
        _timeLeft -= dt;
        if (_timeLeft <= 0) _chooseNextActivity();
      case TurtleActivity.resting:
        _decelerate(dt);
        _updateLook(dt, calm: true);
        _timeLeft -= dt;
        if (_timeLeft <= 0) _enterIdle();
      case TurtleActivity.reacting:
        _decelerate(dt);
        final face = _reactionHeading;
        if (face != null) _turnToward(face, dt, rate: 3.2);
        _updateLook(dt, calm: false);
        _timeLeft -= dt;
        if (_timeLeft <= 0) _enterIdle(seconds: 1.2);
      case TurtleActivity.happy:
        _decelerate(dt);
        _updateLook(dt, calm: false);
        _timeLeft -= dt;
        if (_timeLeft <= 0) _enterIdle();
      case TurtleActivity.feeding:
        _decelerate(dt);
        _updateLook(dt, calm: true);
      case TurtleActivity.turning:
      case TurtleActivity.swimming:
      case TurtleActivity.exploring:
      case TurtleActivity.approachingTarget:
        _travel(dt);
    }
  }

  /// Replace the swim bounds, for example when the widget is resized.
  void updateBounds(TurtleBounds bounds) {
    if (_bounds == bounds) return;
    _bounds = bounds;
    _position = bounds.clamp(_position);
    final target = _target;
    if (target != null) _target = bounds.clamp(target);
  }

  void setAutonomy(TurtleAutonomy autonomy) {
    if (_autonomy == autonomy) return;
    _autonomy = autonomy;

    if (autonomy == TurtleAutonomy.calm || autonomy == TurtleAutonomy.rest) {
      if (_isTravelling) _enterIdle(seconds: 1.2);
    }
    if (autonomy == TurtleAutonomy.rest && _activity == TurtleActivity.idle) {
      _enterRest();
    } else if (autonomy == TurtleAutonomy.free &&
        _activity == TurtleActivity.idle &&
        _timeLeft > 1.2) {
      _timeLeft = 1.2;
    }
  }

  /// Send Tala toward a named point. Used for feeding and future curiosities.
  bool requestFeed(Offset target, {double stopDistance = .05}) {
    if (_activity == TurtleActivity.feeding ||
        _activity == TurtleActivity.happy) {
      return false;
    }
    _feedArriveDistance = stopDistance.clamp(.02, .18).toDouble();
    _beginTrip(_bounds.clamp(target), _TargetPurpose.feed);
    return true;
  }

  /// Leave the feeding pose and play a short happy reaction.
  void finishFeeding({bool celebrate = true}) {
    if (_activity != TurtleActivity.feeding) return;
    if (celebrate) {
      _enterHappy();
    } else {
      _enterIdle();
    }
  }

  /// Acknowledge a tap. Feeding is never interrupted: Tala gives a small nod
  /// and stays in the feeding state so gameplay cannot be corrupted.
  bool reactToPlayer({Offset? from, bool force = false}) {
    if (_activity == TurtleActivity.feeding) {
      _feedNodTime = .7;
      return false;
    }
    if (_activity == TurtleActivity.happy) return false;
    if (!force && _reactionCooldown > 0) return false;

    _reactionCooldown = 2.6;
    _target = null;
    _targetPurpose = _TargetPurpose.none;
    _activity = TurtleActivity.reacting;
    _timeLeft = reactionDuration;
    _stateElapsed = 0;
    if (from != null && (from - _position).distance > .01) {
      _reactionHeading = math.atan2(
        from.dy - _position.dy,
        from.dx - _position.dx,
      );
    } else {
      _reactionHeading = null;
    }
    return true;
  }

  bool celebrate() {
    if (_activity == TurtleActivity.feeding) return false;
    _target = null;
    _targetPurpose = _TargetPurpose.none;
    _enterHappy();
    return true;
  }

  /// Stop the current destination without changing the autonomy mode.
  void cancelTrip() {
    if (!_isTravelling) return;
    _enterIdle(seconds: 1.2);
  }

  TurtlePose get pose {
    final ratio = speedRatio;
    final moving = ratio > .05;
    final activity = _activity;
    final calmPose =
        activity == TurtleActivity.idle ||
        activity == TurtleActivity.resting ||
        activity == TurtleActivity.feeding;

    final intensity = moving ? .45 + .55 * ratio : .32;
    final calmFactor = calmPose ? .45 : 1.0;

    // The model faces +Z (towards the camera), so screen-right travel is a
    // positive yaw about +Y and descending is a negative pitch. Keep the face
    // visible: the body turns up to ~35 degrees, not a full side profile.
    var yaw =
        (math.cos(_heading) * .52 * intensity * calmFactor + _lookOffset * .42)
            .clamp(-.62, .62)
            .toDouble();
    var pitch = (-math.sin(_heading) * .28 * intensity * calmFactor)
        .clamp(-.32, .32)
        .toDouble();
    var roll = (-_lastTurnRate * .06).clamp(-.18, .18).toDouble();

    final resting = activity == TurtleActivity.resting;
    var bob = math.sin(_breathPhase) * (resting ? .004 : .008);
    final paddle = resting || (!moving && !_isExpressive)
        ? 0.0
        : math.sin(_paddlePhase);

    // A swimming body does not stay perfectly level. The paddle rhythm feeds
    // a tiny yaw/roll sway so even a straight line reads as being in water.
    yaw += paddle * .016;
    roll += paddle * .020;

    if (activity == TurtleActivity.happy) {
      final progress = (_stateElapsed / happyDuration).clamp(0.0, 1.0);
      final wiggle = math.sin(progress * math.pi * 5) * (1 - progress);
      yaw += wiggle * .20;
      roll += wiggle * .16;
      bob += math.sin(progress * math.pi) * .05;
    } else if (activity == TurtleActivity.reacting) {
      final progress = (_stateElapsed / reactionDuration).clamp(0.0, 1.0);
      final wiggle = math.sin(progress * math.pi * 6) * (1 - progress);
      yaw += wiggle * .16;
      roll += wiggle * .12;
      bob += math.sin(progress * math.pi) * .035;
    } else if (activity == TurtleActivity.feeding) {
      // A gentle chew nod keeps the pose alive when the model has no jaw clip.
      final chew = math.sin(_stateElapsed * 9.5);
      pitch += chew * .05;
      bob += chew * .006;
    }

    if (_feedNodTime > 0 && activity == TurtleActivity.feeding) {
      final progress = 1 - (_feedNodTime / .7);
      final nod = math.sin(progress * math.pi * 6) * (_feedNodTime / .7);
      yaw += nod * .06;
      bob += nod * .012;
    }

    return TurtlePose(
      position: _position,
      heading: _heading,
      speed: _speed,
      speedRatio: ratio,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      bob: bob,
      paddle: paddle,
      depth: _depth.clamp(-1, 1).toDouble(),
      scale: activity == TurtleActivity.happy
          ? 1 + math.sin((_stateElapsed / happyDuration) * math.pi) * .035
          : 1,
      activity: activity,
    );
  }

  bool get _isTravelling =>
      _activity == TurtleActivity.exploring ||
      _activity == TurtleActivity.turning ||
      _activity == TurtleActivity.swimming ||
      _activity == TurtleActivity.approachingTarget;

  bool get _isExpressive =>
      _activity == TurtleActivity.happy || _activity == TurtleActivity.reacting;

  void _travel(double dt) {
    final target = _target;
    if (target == null) {
      _enterIdle();
      return;
    }

    final delta = target - _position;
    final distance = delta.distance;
    final desiredHeading = math.atan2(delta.dy, delta.dx);
    final error = _wrapAngle(desiredHeading - _heading);

    _turnToward(desiredHeading, dt, rate: turnRate);

    final aligned = math.cos(error).clamp(0.0, 1.0);
    final arrivalRadius = _targetPurpose == _TargetPurpose.feed
        ? _feedArriveDistance
        : arriveDistance;
    final holdingForFood =
        _targetPurpose == _TargetPurpose.feed &&
        distance <= arrivalRadius &&
        error.abs() > .45;

    if (holdingForFood) {
      // Stop beside the food and finish the turn before biting. This prevents
      // eating from a sideways angle when the child drops food very close.
      _activity = TurtleActivity.turning;
      _speed = _approach(_speed, 0, deceleration * dt);
      return;
    }

    if (error.abs() > turnThreshold) {
      _activity = TurtleActivity.turning;
      _speed = _approach(_speed, _turnDriftSpeed, deceleration * dt);
    } else {
      _activity = _targetPurpose == _TargetPurpose.feed
          ? TurtleActivity.approachingTarget
          : TurtleActivity.swimming;
      final distanceFactor = (distance / slowRadius).clamp(.16, 1.0);
      final desiredSpeed = maxSpeed * distanceFactor * (.35 + .65 * aligned);
      _speed = _approach(
        _speed,
        desiredSpeed,
        (desiredSpeed > _speed ? acceleration : deceleration) * dt,
      );
    }

    // Move only along the current heading. Tala never slides sideways while
    // looking in another direction; a tight turn produces a small forward arc.
    if (_speed > 0) {
      _position = _bounds.clamp(
        _position +
            Offset(math.cos(_heading), math.sin(_heading)) * _speed * dt,
      );
    }

    if (distance <= arrivalRadius ||
        (_position - target).distance <= arrivalRadius) {
      _arrive();
    }
  }

  void _arrive() {
    final purpose = _targetPurpose;
    _target = null;
    _targetPurpose = _TargetPurpose.none;
    _speed = math.min(_speed, .02);

    switch (purpose) {
      case _TargetPurpose.feed:
        _activity = TurtleActivity.feeding;
        _timeLeft = 0;
        _stateElapsed = 0;
        _feedArrivedEvent = true;
      case _TargetPurpose.rest:
        _enterRest();
      case _TargetPurpose.explore:
      case _TargetPurpose.none:
        _enterIdle();
    }
  }

  void _chooseNextActivity() {
    switch (_autonomy) {
      case TurtleAutonomy.rest:
        _enterRest();
      case TurtleAutonomy.calm:
        if (_random.nextDouble() < .3) {
          _enterRest();
        } else {
          _enterIdle();
        }
      case TurtleAutonomy.free:
        final roll = _random.nextDouble();
        if (roll < .66) {
          final target = _pickExploreTarget();
          if (target != null) {
            _beginTrip(target, _TargetPurpose.explore);
            return;
          }
        }
        if (roll < .88) {
          _beginRestTrip();
        } else {
          _enterIdle();
        }
    }
  }

  Offset? _pickExploreTarget() {
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = Offset(
        _bounds.minX + _random.nextDouble() * _bounds.width,
        _bounds.minY + _random.nextDouble() * _bounds.height,
      );
      if ((candidate - _position).distance >= .18) return candidate;
    }
    return null;
  }

  void _beginRestTrip() {
    final target = Offset(
      (_position.dx + (_random.nextDouble() - .5) * .3)
          .clamp(_bounds.minX, _bounds.maxX)
          .toDouble(),
      _bounds.maxY - .01,
    );
    if ((target - _position).distance < .08) {
      _enterRest();
    } else {
      _beginTrip(target, _TargetPurpose.rest);
    }
  }

  void _beginTrip(Offset target, _TargetPurpose purpose) {
    _target = target;
    _targetPurpose = purpose;
    _activity = TurtleActivity.exploring;
    _timeLeft = 0;
    _stateElapsed = 0;
    // Feeding happens on the resting depth plane so the seagrass token and the
    // projected mouth agree. Exploring wanders forward and back through the
    // water, which is the strongest depth cue the child sees.
    _depthTarget = purpose == _TargetPurpose.feed
        ? 0
        : (_random.nextDouble() - .5) * 1.4;
  }

  void _enterIdle({double? seconds}) {
    _activity = TurtleActivity.idle;
    _target = null;
    _targetPurpose = _TargetPurpose.none;
    _timeLeft = seconds ?? (2.0 + _random.nextDouble() * 2.2);
    _stateElapsed = 0;
    _lookTimer = .8 + _random.nextDouble() * 1.8;
    _reactionHeading = null;
    _depthTarget = (_random.nextDouble() - .5) * .55;
  }

  void _enterRest() {
    _activity = TurtleActivity.resting;
    _target = null;
    _targetPurpose = _TargetPurpose.none;
    _timeLeft = 4 + _random.nextDouble() * 3.5;
    _stateElapsed = 0;
    _lookTimer = 1.2 + _random.nextDouble() * 2.2;
    _reactionHeading = null;
    _depthTarget = (_random.nextDouble() - .5) * .35;
  }

  void _enterHappy() {
    _activity = TurtleActivity.happy;
    _target = null;
    _targetPurpose = _TargetPurpose.none;
    _timeLeft = happyDuration;
    _stateElapsed = 0;
    _reactionHeading = null;
    // Come toward the child while celebrating.
    _depthTarget = .22;
  }

  void _decelerate(double dt) {
    _lastTurnRate *= math.max(0, 1 - dt * 4);
    if (_speed <= 0) {
      _speed = 0;
      return;
    }
    _speed = math.max(0, _speed - deceleration * dt);
    _position = _bounds.clamp(
      _position + Offset(math.cos(_heading), math.sin(_heading)) * _speed * dt,
    );
  }

  void _turnToward(double desired, double dt, {required double rate}) {
    final error = _wrapAngle(desired - _heading);
    final maxStep = rate * dt;
    final applied = error.clamp(-maxStep, maxStep).toDouble();
    _heading = _wrapAngle(_heading + applied);
    _lastTurnRate = dt > 0 ? applied / dt : 0;
  }

  void _updateLook(double dt, {required bool calm}) {
    if (!calm) {
      _lookOffset += (0 - _lookOffset) * math.min(1, dt * 3);
      return;
    }
    _lookTimer -= dt;
    if (_lookTimer <= 0) {
      _lookTarget = (_random.nextDouble() - .5) * .7;
      _lookTimer = 1.5 + _random.nextDouble() * 2.4;
    }
    _lookOffset += (_lookTarget - _lookOffset) * math.min(1, dt * 1.8);
  }

  static double _approach(double value, double target, double step) {
    if (value < target) return math.min(target, value + step);
    return math.max(target, value - step);
  }

  static double _wrapAngle(double angle) {
    final wrapped = (angle + math.pi) % (2 * math.pi);
    return (wrapped < 0 ? wrapped + 2 * math.pi : wrapped) - math.pi;
  }
}
