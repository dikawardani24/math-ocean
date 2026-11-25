import 'package:material_ui/material_ui.dart';

import '../theme.dart';

enum StationKind { counting, addition, subtraction, jarimatika }

extension StationKindX on StationKind {
  String get id => switch (this) {
    StationKind.counting => 'counting',
    StationKind.addition => 'addition',
    StationKind.subtraction => 'subtraction',
    StationKind.jarimatika => 'jarimatika',
  };

  String get label => switch (this) {
    StationKind.counting => 'Counting',
    StationKind.addition => 'Adding',
    StationKind.subtraction => 'Taking away',
    StationKind.jarimatika => 'Jarimatika',
  };

  String get stationName => switch (this) {
    StationKind.counting => 'Coral Cove',
    StationKind.addition => 'Shell Shore',
    StationKind.subtraction => 'Kelp Forest',
    StationKind.jarimatika => 'Finger Reef',
  };

  String get blurb => switch (this) {
    StationKind.counting => 'Count the treasures of the reef',
    StationKind.addition => 'Gather two groups together',
    StationKind.subtraction => 'Let a few treasures swim away',
    StationKind.jarimatika => 'Magic numbers on your fingers',
  };

  IconData get icon => switch (this) {
    StationKind.counting => Icons.bubble_chart_rounded,
    StationKind.addition => Icons.add_circle_rounded,
    StationKind.subtraction => Icons.remove_circle_rounded,
    StationKind.jarimatika => Icons.back_hand_rounded,
  };

  Color get color => switch (this) {
    StationKind.counting => OceanColors.aqua,
    StationKind.addition => OceanColors.coral,
    StationKind.subtraction => OceanColors.lilac,
    StationKind.jarimatika => OceanColors.sunny,
  };

  Color get deepColor => switch (this) {
    StationKind.counting => const Color(0xFF0E8F91),
    StationKind.addition => const Color(0xFFD95D46),
    StationKind.subtraction => const Color(0xFF6C51BD),
    StationKind.jarimatika => const Color(0xFFD99A26),
  };
}

/// A single playable task.
///
/// Missions are pure data. The Kecrekan and the Jarimatika hand are both
/// driven from [target], never the other way around, so the maths stays the
/// source of truth.
class Mission {
  const Mission({
    required this.id,
    required this.station,
    required this.title,
    required this.story,
    required this.target,
    this.a,
    this.b,
    this.start,
    this.hint = '',
    this.voice = '',
    this.emoji = '🐚',
  });

  final String id;
  final StationKind station;
  final String title;
  final String story;

  /// The number the child must build or show.
  final int target;

  /// Addition operands.
  final int? a;
  final int? b;

  /// Subtraction starting value. Null means start from zero.
  final int? start;

  final String hint;
  final String voice;
  final String emoji;

  /// The frame begins with the first group already represented. Addition
  /// therefore starts at [a], subtraction starts at [start], and counting
  /// starts empty.
  int get startValue => start ??
      (isAddition ? (a ?? 0) : isSubtraction ? target : 0);

  bool get isAddition => station == StationKind.addition;
  bool get isSubtraction => station == StationKind.subtraction;
  bool get isJarimatika => station == StationKind.jarimatika;

  String get equation {
    if (isAddition) return '$a + $b = $target';
    if (isSubtraction) return '$start − $b = $target';
    return '$target';
  }

  /// The prompt version of the equation, with the answer hidden.
  String get question {
    if (isAddition) return '$a + $b = ?';
    if (isSubtraction) return '$start − $b = ?';
    return '$target';
  }

  String get shortPrompt {
    if (isAddition) return 'Make $a + $b';
    if (isSubtraction) return 'Start with $start, take away $b';
    if (isJarimatika) return 'Show $target with your fingers';
    return 'Make $target';
  }
}

class Treasure {
  const Treasure({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.color,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;
  final Color color;
}

class StationInfo {
  const StationInfo({required this.kind, required this.tagline});
  final StationKind kind;
  final String tagline;
}
