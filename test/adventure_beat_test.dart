import 'package:flutter_test/flutter_test.dart';
import 'package:math_ocean/adventure/adventure_beat.dart';

void main() {
  test('beat runner follows the teaching sequence', () {
    final runner = BeatRunner();
    expect(runner.current, AdventureBeat.demo);
    expect(runner.canInteract, isFalse);

    runner.advance();
    expect(runner.current, AdventureBeat.narrate);
    runner.advance();
    expect(runner.current, AdventureBeat.highlight);
    runner.advance();
    expect(runner.current, AdventureBeat.invite);
    expect(runner.awaitingChild, isTrue);
    expect(runner.canInteract, isTrue);

    runner.goTo(AdventureBeat.freePlay);
    expect(runner.isComplete, isTrue);
  });

  test('offerHelp jumps to the help beat', () {
    final runner = BeatRunner();
    runner.goTo(AdventureBeat.invite);
    runner.offerHelp();
    expect(runner.current, AdventureBeat.help);
    expect(runner.canInteract, isTrue);
  });
}
