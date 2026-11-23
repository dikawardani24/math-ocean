import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/core/catalog.dart';
import 'package:math_ocean/core/models.dart';
import 'package:math_ocean/core/progress.dart';

void main() {
  test('recordSuccess keeps the best stars and awards pearls', () {
    final progress = ProgressController.inMemory();
    final mission = missionsFor(StationKind.counting).first;
    final reward = progress.recordSuccess(mission, stars: 2, firstTry: false);
    expect(reward, 1);
    expect(progress.starsFor(mission.id), 2);
    expect(progress.pearls, 1);
    progress.recordSuccess(mission, stars: 1, firstTry: false);
    expect(progress.starsFor(mission.id), 2);
    expect(progress.pearls, 2);
  });

  test('first-try answers build mastery evidence', () {
    final progress = ProgressController.inMemory();
    for (final mission in missionsFor(StationKind.counting)) {
      progress.recordSuccess(mission, stars: 3, firstTry: true);
    }
    expect(progress.firstTryFor(StationKind.counting), 4);
    for (final mission in missionsFor(StationKind.addition).take(2)) {
      progress.recordSuccess(mission, stars: 3, firstTry: true);
    }
    progress.recordSuccess(
      missionsFor(StationKind.subtraction).first,
      stars: 3,
      firstTry: true,
    );
    expect(progress.jarimatikaChallengeUnlocked, isTrue);
  });

  test('walkthrough taps alone do not unlock the challenge', () {
    final progress = ProgressController.inMemory();
    for (final mission in kMissions) {
      progress.recordSuccess(mission, stars: 1, firstTry: false);
    }
    expect(progress.jarimatikaChallengeUnlocked, isFalse);
  });

  test('missions unlock in order inside a station', () {
    final progress = ProgressController.inMemory();
    final list = missionsFor(StationKind.addition);
    expect(progress.isMissionUnlocked(list[0]), isTrue);
    expect(progress.isMissionUnlocked(list[1]), isFalse);
    progress.recordSuccess(list[0], stars: 1, firstTry: false);
    expect(progress.isMissionUnlocked(list[1]), isTrue);
  });

  test('a chest costs pearls and yields a new treasure', () {
    final progress = ProgressController.inMemory();
    expect(progress.openChest(), isNull);
    progress.addPearls(3);
    final id = progress.openChest();
    expect(id, isNotNull);
    expect(progress.treasures, contains(id));
    expect(progress.pearls, 0);
  });

  test('state survives a serialized round trip', () {
    final progress = ProgressController.inMemory();
    progress.recordSuccess(
      missionsFor(StationKind.counting).first,
      stars: 3,
      firstTry: true,
    );
    final map = progress.toJsonForTesting();
    final restored = ProgressController.inMemory(map);
    expect(restored.totalStars, 3);
    expect(restored.pearls, 2);
    expect(restored.firstTryFor(StationKind.counting), 1);
  });

  test('challenge and adventure stars count toward totalStars', () {
    final progress = ProgressController.inMemory();
    final challenge = randomChallengeFor(
      StationKind.counting,
      random: math.Random(1),
    );
    progress.recordSuccess(challenge, stars: 3, firstTry: true);
    expect(progress.totalStars, 3);
  });

  test('discovering creatures and completing Coral Cove unlocks Shell Shore', () {
    final progress = ProgressController.inMemory();
    expect(progress.isLocationUnlocked('coral_cove'), isTrue);
    expect(progress.isLocationUnlocked('shell_shore'), isFalse);
    expect(progress.discoverCreature('green_turtle'), isTrue);
    expect(progress.discoverCreature('green_turtle'), isFalse);
    progress.completeAdventure('coral_cove');
    expect(progress.hasCompletedAdventure('coral_cove'), isTrue);
    expect(progress.isLocationUnlocked('shell_shore'), isTrue);
    expect(progress.discoveryCount, 1);
  });

  test('discovery state survives a round trip', () {
    final progress = ProgressController.inMemory();
    progress.discoverCreature('clownfish');
    progress.completeAdventure('coral_cove');
    final restored = ProgressController.inMemory(progress.toJsonForTesting());
    expect(restored.hasDiscovered('clownfish'), isTrue);
    expect(restored.hasCompletedAdventure('coral_cove'), isTrue);
    expect(restored.isLocationUnlocked('shell_shore'), isTrue);
  });
}
