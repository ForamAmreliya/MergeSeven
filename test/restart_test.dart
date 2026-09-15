import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_seven/core/services/audio_service.dart';
import 'package:merge_seven/main.dart';
import 'package:merge_seven/providers/game_provider.dart';
import 'package:merge_seven/screens/game_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameProvider> openGame(WidgetTester tester, Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues({'savedGame': jsonEncode(saved), 'tutorialSeen': true});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(MergeSevenApp(prefs: prefs, audio: AudioService()..soundOn = false));
  await tester.pump(const Duration(milliseconds: 100));
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return tester.element(find.byType(GameScreen)).read<GameProvider>();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('pause > restart keeps level 6', (tester) async {
    final game = await openGame(tester, {
      'tiles': [
        [0, 0, 64],
        [1, 0, 32],
      ],
      'tray': [
        {
          'v': [2],
          't': 0,
        },
        {
          'v': [4],
          't': 0,
        },
        {
          'v': [8],
          't': 0,
        },
      ],
      'score': 3288,
      'level': 6,
      'xp': 50,
      'goal': 256,
      'peak': 128,
    });
    expect(game.level, 6);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await settle(tester);
    await tester.tap(find.text('RESTART'));
    await settle(tester);
    expect(game.level, 6);
    expect(game.xp, 50);
    expect(game.tiles, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
