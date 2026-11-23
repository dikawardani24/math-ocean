/// Teaching beats used inside adventures.
///
/// Sequence: demo → narrate → highlight → invite → respond → help → free play.
/// Teaching happens in the game world, never as a static dialog page.
enum AdventureBeat {
  demo,
  narrate,
  highlight,
  invite,
  respond,
  help,
  freePlay,
}

/// Pure state machine for guided teaching inside an activity.
class BeatRunner {
  BeatRunner({
    List<AdventureBeat> sequence = const [
      AdventureBeat.demo,
      AdventureBeat.narrate,
      AdventureBeat.highlight,
      AdventureBeat.invite,
      AdventureBeat.respond,
      AdventureBeat.help,
      AdventureBeat.freePlay,
    ],
  }) : _sequence = List.unmodifiable(sequence);

  final List<AdventureBeat> _sequence;
  int _index = 0;
  AdventureBeat? _override;

  AdventureBeat get current => _override ?? _sequence[_index];
  bool get isComplete =>
      _override == null &&
      _index >= _sequence.length - 1 &&
      current == AdventureBeat.freePlay;
  bool get awaitingChild =>
      current == AdventureBeat.invite || current == AdventureBeat.respond;
  bool get canInteract =>
      current == AdventureBeat.invite ||
      current == AdventureBeat.respond ||
      current == AdventureBeat.help ||
      current == AdventureBeat.freePlay;

  void advance() {
    _override = null;
    if (_index < _sequence.length - 1) _index++;
  }

  void goTo(AdventureBeat beat) {
    _override = null;
    final i = _sequence.indexOf(beat);
    if (i >= 0) {
      _index = i;
    } else {
      _override = beat;
    }
  }

  void offerHelp() => goTo(AdventureBeat.help);

  void reset() {
    _override = null;
    _index = 0;
  }
}
