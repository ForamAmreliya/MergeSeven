import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The app's version, read from pubspec.yaml at start-up.
///
/// Screens show [label], so bumping `version:` in pubspec.yaml is enough to
/// update every place the version appears.
class AppInfo {
  AppInfo._();

  /// The version name only, e.g. "v1.0.1" (no build number).
  /// Empty until [load] finishes.
  static String label = '';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isEmpty) return;
      label = 'v${info.version}';
    } catch (e) {
      debugPrint('Could not read the app version: $e');
    }
  }
}
