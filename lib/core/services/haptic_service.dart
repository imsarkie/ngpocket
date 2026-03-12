import 'package:flutter/services.dart';

class HapticService {
  Future<void> light() {
    return HapticFeedback.lightImpact();
  }

  Future<void> medium() {
    return HapticFeedback.mediumImpact();
  }

  Future<void> selection() {
    return HapticFeedback.selectionClick();
  }

  Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.selectionClick();
  }
}
