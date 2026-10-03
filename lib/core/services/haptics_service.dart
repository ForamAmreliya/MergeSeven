import 'package:flutter/services.dart';

enum HapticStrength { light, medium, heavy }

/// Vibration feedback. The game has no sound at all, so this is the only
/// feedback service.
class HapticsService {
  bool hapticsOn = true;

  void haptic([HapticStrength strength = HapticStrength.light]) {
    if (!hapticsOn) return;
    switch (strength) {
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}
