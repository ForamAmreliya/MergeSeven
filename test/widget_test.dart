import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_seven/main.dart';
import 'package:merge_seven/screens/game_screen.dart';
import 'package:merge_seven/widgets/board/board_view.dart';
import 'package:provider/provider.dart';
import 'package:merge_seven/core/services/audio_service.dart';
import 'package:merge_seven/models/hex_coord.dart';
import 'package:merge_seven/models/piece.dart';
import 'package:merge_seven/providers/game_provider.dart';
import 'package:merge_seven/providers/player_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAudio extends AudioService {
  _SilentAudio() {
    soundOn = false;
    hapticsOn = false;
  }
}

Future<GameProvider> _game([Map<String, Object?>? saved]) async {
  SharedPreferences.setMockInitialValues({if (saved != null) 'savedGame': jsonEncode(saved)});
  final prefs = await SharedPreferences.getInstance();
  return GameProvider(prefs, PlayerProvider(prefs), _SilentAudio());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('board has 37 cells', () {
    expect(GameProvider.cells.length, 37);
    expect(GameProvider.isOnBoard(const HexCoord(3, -3)), isTrue);
    expect(GameProvider.isOnBoard(const HexCoord(3, 1)), isFalse);
  });

  test('pixel conversion round-trips', () {
    for (final c in GameProvider.cells) {
      expect(HexCoord.fromPixel(c.toPixel(20), 20), c);
    }
  });

  test('pair piece rotates through six orientations', () {
    var p = Piece([2, 4]);
    final seen = <HexCoord>{};
    for (var i = 0; i < 6; i++) {
      seen.add(p.cellsAt(const HexCoord(0, 0))[1]);
      p = p.rotated();
    }
    expect(seen.length, 6);
  });

  test('placing a new game piece fills its cells', () async {
    final game = await _game();
    game.newGame();
    final piece = game.tray[0]!;
    const anchor = HexCoord(0, 0);
    final cells = piece.cellsAt(anchor);
    expect(game.canPlace(piece, anchor), isTrue);
    await game.place(0, anchor);
    // Either tiles remain on those cells or they merged into the anchor.
    expect(game.isEmpty(cells.first), isFalse);
    expect(game.busy, isFalse);
  });

  Map<String, Object?> state(List<List<int>> tiles, List<List<int>> tray, {int turns = 0}) => {
    'tiles': tiles,
    'tray': [
      for (final v in tray) {'v': v, 't': turns},
    ],
    'score': 0,
    'level': 1,
    'xp': 0,
    'goal': 32,
    'peak': 8,
  };

  List<List<int>> fullBoardExcept(Set<HexCoord> holes) => [
    for (final c in GameProvider.cells)
      if (!holes.contains(c))
        [
          c.q,
          c.r,
          const [2, 4, 8, 16, 32, 64][(c.q * 2 + c.r * 5 + 18) % 6],
        ],
  ];

  test('two matching tiles do not merge', () async {
    final game = await _game(
      state([], [
        [2, 2],
      ]),
    );
    await game.place(0, const HexCoord(-2, 2));
    expect(game.tiles.length, 2);
    expect(game.score, 0);
  });

  test('three matching tiles merge into double value', () async {
    final game = await _game(
      state(
        [
          [1, 0, 2],
          [-1, 0, 2],
        ],
        [
          [2],
        ],
      ),
    );
    await game.place(0, const HexCoord(0, 0));
    expect(game.tiles.length, 1);
    expect(game.tiles.single.value, 4);
    expect(game.tiles.single.pos, const HexCoord(0, 0));
    expect(game.score, greaterThan(0));
  });

  test('game is over only when none of the pieces has room', () async {
    final holes = {const HexCoord(0, 0)};
    final stuck = await _game(
      state(fullBoardExcept(holes), [
        [2, 4],
        [8, 16],
      ]),
    );
    expect(stuck.gameOver, isTrue);

    final oneFits = await _game(
      state(fullBoardExcept(holes), [
        [2, 4],
        [128],
      ]),
    );
    expect(oneFits.gameOver, isFalse);
  });

  test('using all three pieces deals a new set', () async {
    final game = await _game(
      state([], [
        [2],
        [4],
        [8],
      ]),
    );
    await game.place(0, const HexCoord(-3, 0));
    await game.place(1, const HexCoord(3, 0));
    expect(game.tray.whereType<Object>().length, 1);
    await game.place(2, const HexCoord(0, 3));
    expect(game.tray.every((p) => p != null), isTrue);
  });

  test('a new game deals only 2s', () async {
    final game = await _game();
    for (var i = 0; i < 40; i++) {
      game.newGame();
      for (final p in game.tray) {
        expect(p!.values.every((v) => v == 2), isTrue);
      }
    }
  });

  test('bigger numbers unlock as the game grows', () async {
    // Best tile so far is 32, so pieces can carry 2, 4 and 8.
    final seen = <int>{};
    for (var i = 0; i < 60; i++) {
      final game = await _game({...state([], []), 'peak': 32});
      for (final p in game.tray) {
        seen.addAll(p!.values);
      }
    }
    expect(seen, containsAll([2, 4, 8]));
    expect(seen.every((v) => v <= 16), isTrue);
  });

  test('pieces cannot be rotated, so a pair only fits in its own direction', () async {
    // Only two holes left, side by side: (0,0) and (1,0).
    final holes = {const HexCoord(0, 0), const HexCoord(1, 0)};
    final pair = [
      [128, 256],
    ];
    final sideways = await _game(state(fullBoardExcept(holes), pair, turns: 0));
    expect(sideways.gameOver, isFalse);
    final downward = await _game(state(fullBoardExcept(holes), pair, turns: 1));
    expect(downward.gameOver, isTrue);
  });

  testWidgets('dragging the piece onto the board places it', (tester) async {
    SharedPreferences.setMockInitialValues({'tutorialSeen': true});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MergeSevenApp(prefs: prefs, audio: _SilentAudio()));
    await tester.pump(const Duration(milliseconds: 100));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final game = tester.element(find.byType(GameScreen)).read<GameProvider>();
    expect(game.tiles, isEmpty);

    final tray = tester.getCenter(find.byKey(const ValueKey('slot0')));
    final board = tester.getCenter(find.byType(BoardView));
    final lift = tester.widget<BoardView>(find.byType(BoardView)).drag.geometry!.cell * 2.4;
    final gesture = await tester.startGesture(tray);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(tray, board + Offset(0, lift), i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.tiles, isNotEmpty);
    expect(game.busy, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
