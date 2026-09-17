import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx { place, click, error, coin, smash, levelUp, gameOver }

/// Low-latency sound effects, spoken praise and haptics.
///
/// Every clip is preloaded into a few players whose volume is set once. Playing
/// then costs a single platform call (`resume`), so sounds are heard right when
/// the player taps instead of trailing behind. Free players are picked by
/// tracking when each clip finishes, so a busy player is never interrupted
/// unless every player is in use.
class AudioService {
  bool soundOn = true;
  bool hapticsOn = true;
  bool voiceOn = true;

  final Map<String, _Clip> _clips = {};

  /// The praise clip currently being spoken (only one at a time).
  _Clip? _speaking;
  DateTime _lastSpoken = DateTime.fromMillisecondsSinceEpoch(0);

  /// File name, how many players it needs, and its volume.
  static const _files = {
    Sfx.place: ('place.wav', 3, 1.0),
    Sfx.click: ('click.wav', 2, 0.7),
    Sfx.error: ('error.wav', 2, 0.5),
    Sfx.coin: ('coin.wav', 2, 0.8),
    Sfx.smash: ('smash.wav', 2, 1.0),
    Sfx.levelUp: ('levelup.wav', 1, 1.0),
    Sfx.gameOver: ('gameover.wav', 1, 1.0),
  };

  /// Recorded praise words (neural TTS voice), keyed by file name.
  static const _voiceClips = [
    'good_job',
    'nice',
    'well_done',
    'excellent',
    'great',
    'perfect',
    'amazing',
    'unbelievable',
    'incredible',
  ];

  Future<void> init() async {
    try {
      // Play alongside the user's music instead of stealing audio focus.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('Audio context setup failed: $e');
    }

    final wanted = <String, (int, double)>{
      for (final entry in _files.values) entry.$1: (entry.$2, entry.$3),
      for (var i = 1; i <= 5; i++) 'merge$i.wav': (2, 0.9),
      for (final v in _voiceClips) 'voice/$v.mp3': (1, 1.0),
    };

    for (final entry in wanted.entries) {
      final (count, volume) = entry.value;
      try {
        final players = <AudioPlayer>[];
        for (var i = 0; i < count; i++) {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource('sounds/${entry.key}'));
          await player.setVolume(volume);
          players.add(player);
        }
        final length = await players.first.getDuration();
        _clips[entry.key] = _Clip(players, length ?? const Duration(milliseconds: 400));
      } catch (e) {
        debugPrint('Audio preload failed for ${entry.key}: $e');
      }
    }
  }

  void play(Sfx sfx) => _clips[_files[sfx]!.$1]?.play();

  /// Merge chime that rises in pitch with the combo count.
  void merge(int combo) => _clips['merge${combo.clamp(1, 5)}.wav']?.play();

  /// Speaks a praise word such as "GOOD JOB!".
  ///
  /// Only one praise word is ever spoken at a time: a new word stops the
  /// previous one instead of talking over it.
  void speak(String text) {
    if (!voiceOn || !soundOn) return;
    final name = text.toLowerCase().replaceAll(RegExp('[^a-z]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final clip = _clips['voice/$name.mp3'];
    if (clip == null) return;
    final now = DateTime.now();
    // Ignore a second cheer that arrives right on top of the previous one.
    if (now.difference(_lastSpoken) < const Duration(milliseconds: 350)) return;
    _lastSpoken = now;
    _speaking?.stop();
    _speaking = clip;
    clip.play();
  }

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

  /// Stops everything (used when the app goes to the background).
  void stopAll() {
    for (final clip in _clips.values) {
      clip.stop();
    }
  }
}

/// One preloaded sound and its players.
class _Clip {
  _Clip(this.players, this.length) : _busyUntil = List.filled(players.length, DateTime.fromMillisecondsSinceEpoch(0));

  final List<AudioPlayer> players;
  final Duration length;
  final List<DateTime> _busyUntil;
  int _next = 0;

  void play() {
    final now = DateTime.now();
    // Prefer a player that has finished: then a single `resume` call is enough.
    var index = -1;
    for (var i = 0; i < players.length; i++) {
      if (now.isAfter(_busyUntil[i])) {
        index = i;
        break;
      }
    }
    final restart = index < 0;
    if (restart) {
      index = _next % players.length;
      _next = index + 1;
    }
    _busyUntil[index] = now.add(length);
    final player = players[index];
    if (restart) {
      player.stop().then((_) => player.resume()).catchError((_) {});
    } else {
      player.resume().catchError((_) {});
    }
  }

  void stop() {
    for (var i = 0; i < players.length; i++) {
      _busyUntil[i] = DateTime.fromMillisecondsSinceEpoch(0);
      players[i].stop().catchError((_) {});
    }
  }
}

enum HapticStrength { light, medium, heavy }
