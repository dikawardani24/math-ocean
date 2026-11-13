import 'package:flutter/services.dart';

abstract final class Feel {
  static Future<void> tap() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> snap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> nope() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
