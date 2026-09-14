import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx { place, click, error, coin, smash, levelUp, gameOver }

/// Low-latency sound effects + haptics.
///
/// Every sound owns a small, fixed set of preloaded players that are reused in
/// turn. Nothing is created while playing, so sounds never cause frame drops
/// or a slow build-up of native players during long sessions.
class AudioService {
  bool soundOn = true;
  bool hapticsOn = true;
  bool voiceOn = true;

  static const _voices = 2;

  final Map<String, List<AudioPlayer>> _players = {};
  final Map<String, int> _cursor = {};

  static const _files = {
    Sfx.place: 'place.wav',
    Sfx.click: 'click.wav',
    Sfx.error: 'error.wav',
    Sfx.coin: 'coin.wav',
    Sfx.smash: 'smash.wav',
    Sfx.levelUp: 'levelup.wav',
    Sfx.gameOver: 'gameover.wav',
  };

  Future<void> init() async {
    try {
      // Play alongside the user's music instead of stealing audio focus.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('Audio context setup failed: $e');
    }
    final names = [
      ..._files.values,
      for (var i = 1; i <= 5; i++) 'merge$i.wav',
      for (final v in _voiceClips) 'voice/$v.mp3',
    ];
    for (final name in names) {
      try {
        final voices = <AudioPlayer>[];
        for (var i = 0; i < _voices; i++) {
          final player = AudioPlayer();
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setSource(AssetSource('sounds/$name'));
          voices.add(player);
        }
        _players[name] = voices;
      } catch (e) {
        debugPrint('Audio preload failed for $name: $e');
      }
    }
  }

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

  void play(Sfx sfx, {double volume = 1}) => _play(_files[sfx]!, volume);

  /// Speaks a praise word such as "GOOD JOB!" if a clip exists for it.
  void speak(String text) {
    if (!voiceOn || !soundOn) return;
    final name = text.toLowerCase().replaceAll(RegExp('[^a-z]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (!_voiceClips.contains(name)) return;
    _play('voice/$name.mp3', 1);
  }

  /// Merge chime that rises in pitch with the combo count.
  void merge(int combo) => _play('merge${combo.clamp(1, 5)}.wav', 0.9);

  void _play(String name, double volume) {
    if (!soundOn) return;
    final voices = _players[name];
    if (voices == null) return;
    final index = (_cursor[name] ?? 0) % voices.length;
    _cursor[name] = index + 1;
    final player = voices[index];
    () async {
      try {
        await player.stop();
        if (player.volume != volume) await player.setVolume(volume);
        await player.resume();
      } catch (_) {
        // A missed sound effect is never worth interrupting the game.
      }
    }();
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
}

enum HapticStrength { light, medium, heavy }
