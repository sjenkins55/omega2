import 'package:flutter/services.dart';

class HapticManager {
  static void light()     => HapticFeedback.lightImpact();
  static void medium()    => HapticFeedback.mediumImpact();
  static void heavy()     => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success()   => HapticFeedback.mediumImpact();
  static void warning()   => HapticFeedback.heavyImpact();
  static void error()     => HapticFeedback.vibrate();
}
