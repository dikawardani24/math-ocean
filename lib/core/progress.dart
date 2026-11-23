import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalog.dart';
import 'models.dart';

class MasteryGoal {
  const MasteryGoal(this.label, this.current, this.goal, this.emoji);
  final String label;
  final int current;
  final int goal;
  final String emoji;

  bool get done => current >= goal;
  double get fraction => (current / goal).clamp(0.0, 1.0);
}

/// All durable game state.
///
/// Progress is deliberately evidence based: the Finger Reef challenge opens
/// from first-try correct answers, not from tapping through menus. Practice is
/// never blocked, so a child can always keep playing while they build mastery.
class ProgressController extends ChangeNotifier {
  ProgressController._(this._prefs);

  static const storageKey = 'math_ocean.progress.v1';

  final SharedPreferences? _prefs;

  final Map<String, int> _stars = {};
  final Set<String> _treasures = {};
  final Map<String, int> _correct = {};
  final Map<String, int> _firstTry = {};
  final Set<String> _seenTips = {};

  int _pearls = 0;
  int _jarimatikaCorrect = 0;
  int _jarimatikaBestStreak = 0;
  int _jarimatikaPlays = 0;
  int _totalCorrect = 0;
  bool _soundOn = true;
  bool _voiceOn = true;
  bool _ambienceOn = true;
  String? _lastMissionId;

  static Future<ProgressController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = ProgressController._(prefs);
    controller._read(prefs.getString(storageKey));
    return controller;
  }

  /// Used by widget tests, where no platform channel is available.
  factory ProgressController.inMemory([Map<String, Object?>? seed]) {
    final controller = ProgressController._(null);
    if (seed != null) controller._applyMap(seed);
    return controller;
  }

  // ── reads ────────────────────────────────────────────────────────────────

  int get pearls => _pearls;
  int get totalCorrect => _totalCorrect;
  int get jarimatikaCorrect => _jarimatikaCorrect;
  int get jarimatikaBestStreak => _jarimatikaBestStreak;
  int get jarimatikaPlays => _jarimatikaPlays;
  bool get soundOn => _soundOn;
  bool get voiceOn => _voiceOn;
  bool get ambienceOn => _ambienceOn;
  String? get lastMissionId => _lastMissionId;
  Set<String> get treasures => Set.unmodifiable(_treasures);
  int get treasureCount => _treasures.length;

  int starsFor(String missionId) => _stars[missionId] ?? 0;

  int stationStars(StationKind kind) =>
      missionsFor(kind).fold(0, (sum, m) => sum + starsFor(m.id));

  int get totalStars =>
      kMissions.fold(0, (sum, mission) => sum + starsFor(mission.id));

  int get completedMissions =>
      kMissions.where((m) => starsFor(m.id) > 0).length;

  int correctFor(StationKind kind) => _correct[kind.id] ?? 0;
  int firstTryFor(StationKind kind) => _firstTry[kind.id] ?? 0;

  bool isMissionComplete(Mission mission) => starsFor(mission.id) > 0;

  /// Missions in a station unlock one at a time. The first is always open.
  bool isMissionUnlocked(Mission mission) {
    final list = missionsFor(mission.station);
    final index = list.indexWhere((m) => m.id == mission.id);
    if (index <= 0) return true;
    return starsFor(list[index - 1].id) > 0;
  }

  bool isStationUnlocked(StationKind kind) {
    if (kind == StationKind.jarimatika) return true; // practice is always open
    final list = missionsFor(kind);
    return list.isEmpty || isMissionUnlocked(list.first);
  }

  /// Finger Reef challenge is earned from clean, first-try maths.
  bool get jarimatikaChallengeUnlocked =>
      firstTryFor(StationKind.counting) >= 3 &&
      firstTryFor(StationKind.addition) >= 2 &&
      firstTryFor(StationKind.subtraction) >= 1 &&
      totalStars >= 8;

  List<MasteryGoal> get masteryGoals => [
    MasteryGoal('Count cleanly', firstTryFor(StationKind.counting), 3, '💧'),
    MasteryGoal('Add cleanly', firstTryFor(StationKind.addition), 2, '➕'),
    MasteryGoal(
      'Take away cleanly',
      firstTryFor(StationKind.subtraction),
      1,
      '➖',
    ),
    MasteryGoal('Collect stars', totalStars, 8, '⭐'),
  ];

  /// The next unplayed mission in a station, for the big "Dive in" button.
  Mission? nextMission(StationKind kind) {
    for (final mission in missionsFor(kind)) {
      if (starsFor(mission.id) == 0) return mission;
    }
    return missionsFor(kind).lastOrNull;
  }

  bool hasSeenTip(String id) => _seenTips.contains(id);

  // ── writes ───────────────────────────────────────────────────────────────

  void markTipSeen(String id) {
    if (_seenTips.add(id)) {
      _persist();
      notifyListeners();
    }
  }

  /// Records a completed mission. Returns the pearls awarded.
  int recordSuccess(
    Mission mission, {
    required int stars,
    required bool firstTry,
  }) {
    final previous = starsFor(mission.id);
    if (stars > previous) _stars[mission.id] = stars;
    _totalCorrect++;
    _correct.update(mission.station.id, (v) => v + 1, ifAbsent: () => 1);
    if (firstTry) {
      _firstTry.update(mission.station.id, (v) => v + 1, ifAbsent: () => 1);
    }
    if (mission.station == StationKind.jarimatika) {
      _jarimatikaCorrect++;
      if (firstTry && stars == 3) {
        _jarimatikaBestStreak++;
      }
    }
    final reward = firstTry ? 2 : 1;
    _pearls += reward;
    _lastMissionId = mission.id;
    _persist();
    notifyListeners();
    return reward;
  }

  void recordPractice({
    required StationKind kind,
    required bool firstTry,
    required bool correct,
  }) {
    if (kind == StationKind.jarimatika) {
      _jarimatikaPlays++;
      if (correct) {
        _jarimatikaCorrect++;
        if (firstTry) _jarimatikaBestStreak++;
      }
    }
    if (correct) {
      _totalCorrect++;
      _correct.update(kind.id, (v) => v + 1, ifAbsent: () => 1);
      if (firstTry) {
        _firstTry.update(kind.id, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    _lastMissionId = null;
    _persist();
    notifyListeners();
  }

  void addPearls(int amount) {
    _pearls += amount;
    _persist();
    notifyListeners();
  }

  /// Opens one treasure chest. Returns the treasure id, or null when the child
  /// cannot afford it / has everything.
  String? openChest({int cost = 3}) {
    if (_pearls < cost) return null;
    final missing = kTreasures
        .where((t) => !_treasures.contains(t.id))
        .toList();
    if (missing.isEmpty) return null;
    _pearls -= cost;
    final pick = missing[(_treasures.length + _totalCorrect) % missing.length];
    _treasures.add(pick.id);
    _persist();
    notifyListeners();
    return pick.id;
  }

  void setSound(bool value) {
    _soundOn = value;
    _persist();
    notifyListeners();
  }

  void setVoice(bool value) {
    _voiceOn = value;
    _persist();
    notifyListeners();
  }

  void setAmbience(bool value) {
    _ambienceOn = value;
    _persist();
    notifyListeners();
  }

  void resetAll() {
    _stars.clear();
    _treasures.clear();
    _correct.clear();
    _firstTry.clear();
    _seenTips.clear();
    _pearls = 0;
    _jarimatikaCorrect = 0;
    _jarimatikaBestStreak = 0;
    _jarimatikaPlays = 0;
    _totalCorrect = 0;
    _lastMissionId = null;
    _persist();
    notifyListeners();
  }

  // ── persistence ──────────────────────────────────────────────────────────

  Map<String, Object?> _toMap() => {
    'stars': _stars,
    'pearls': _pearls,
    'treasures': _treasures.toList(),
    'correct': _correct,
    'firstTry': _firstTry,
    'seenTips': _seenTips.toList(),
    'jarimatikaCorrect': _jarimatikaCorrect,
    'jarimatikaBestStreak': _jarimatikaBestStreak,
    'jarimatikaPlays': _jarimatikaPlays,
    'totalCorrect': _totalCorrect,
    'sound': _soundOn,
    'voice': _voiceOn,
    'ambience': _ambienceOn,
    'lastMission': _lastMissionId,
  };

  /// The exact save payload, exposed so persistence can be verified in tests.
  Map<String, Object?> toJsonForTesting() => _toMap();

  void _applyMap(Map<String, Object?> map) {
    Map<String, int> ints(Object? raw) => {
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
    };

    _stars
      ..clear()
      ..addAll(ints(map['stars']));
    _correct
      ..clear()
      ..addAll(ints(map['correct']));
    _firstTry
      ..clear()
      ..addAll(ints(map['firstTry']));
    _treasures
      ..clear()
      ..addAll((map['treasures'] as List?)?.map((e) => '$e') ?? const []);
    _seenTips
      ..clear()
      ..addAll((map['seenTips'] as List?)?.map((e) => '$e') ?? const []);
    _pearls = (map['pearls'] as num?)?.toInt() ?? 0;
    _jarimatikaCorrect = (map['jarimatikaCorrect'] as num?)?.toInt() ?? 0;
    _jarimatikaBestStreak = (map['jarimatikaBestStreak'] as num?)?.toInt() ?? 0;
    _jarimatikaPlays = (map['jarimatikaPlays'] as num?)?.toInt() ?? 0;
    _totalCorrect = (map['totalCorrect'] as num?)?.toInt() ?? 0;
    _soundOn = map['sound'] as bool? ?? true;
    _voiceOn = map['voice'] as bool? ?? true;
    _ambienceOn = map['ambience'] as bool? ?? true;
    _lastMissionId = map['lastMission'] as String?;
  }

  void _read(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) _applyMap(decoded.cast<String, Object?>());
    } catch (_) {
      // A corrupt save should never keep a child out of the game.
    }
  }

  void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(prefs.setString(storageKey, jsonEncode(_toMap())));
  }
}

class ProgressScope extends InheritedNotifier<ProgressController> {
  const ProgressScope({
    super.key,
    required ProgressController controller,
    required super.child,
  }) : super(notifier: controller);

  static ProgressController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'ProgressScope is missing above this widget.');
    return scope!.notifier!;
  }

  static ProgressController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'ProgressScope is missing above this widget.');
    return scope!.notifier!;
  }
}
