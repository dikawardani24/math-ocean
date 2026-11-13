import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Sound effects, ocean ambience and the spoken guide.
///
/// Every call is defensive: a missing audio device, a tablet with TTS disabled
/// or a widget test without plugins must never break the game.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final List<AudioPlayer> _pool = List.generate(
    5,
    (index) => AudioPlayer(playerId: 'mo-sfx-$index'),
  );
  late final AudioPlayer _ambience = AudioPlayer(playerId: 'mo-ambience');

  FlutterTts? _tts;
  bool _ready = false;
  bool _ambiencePlaying = false;
  int _next = 0;
  int _speakToken = 0;

  bool soundOn = true;
  bool voiceOn = true;
  bool ambienceOn = true;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    // The emulator and some low-end tablets can leave a media player stuck in
    // "preparing" forever. Fail fast instead of blocking a tap for 30 seconds.
    AudioPlayer.preparationTimeout = const Duration(seconds: 6);
    try {
      for (final player in _pool) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.setVolume(0.16);
    } catch (error) {
      debugPrint('Audio players unavailable: $error');
    }
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.43);
      await tts.setPitch(1.08);
      await tts.setVolume(0.9);
      await tts.awaitSpeakCompletion(false);
      _tts = tts;
    } catch (error) {
      debugPrint('TTS unavailable: $error');
    }
    if (ambienceOn) await startAmbience();
  }

  Future<void> startAmbience() async {
    if (_ambiencePlaying || !ambienceOn) return;
    try {
      await _ambience.play(
        AssetSource('audio/ambience/ocean_ambience.wav'),
        volume: 0.16,
      );
      _ambiencePlaying = true;
    } catch (error) {
      debugPrint('Ambience unavailable: $error');
    }
  }

  Future<void> stopAmbience() async {
    _ambiencePlaying = false;
    try {
      await _ambience.stop();
    } catch (_) {}
  }

  Future<void> setAmbienceEnabled(bool value) async {
    ambienceOn = value;
    if (value) {
      await startAmbience();
    } else {
      await stopAmbience();
    }
  }

  Future<void> sfx(String name, {double volume = 0.85}) async {
    if (!soundOn) return;
    try {
      final player = _pool[_next++ % _pool.length];
      await player.play(AssetSource('audio/sfx/$name.wav'), volume: volume);
    } catch (error) {
      debugPrint('SFX $name unavailable: $error');
    }
  }

  Future<void> bead() => sfx('bead_slide', volume: 0.55);
  Future<void> snap() => sfx('bead_snap', volume: 0.8);
  Future<void> groupFive() => sfx('group_five', volume: 0.7);

  Future<void> speak(String text) async {
    if (!voiceOn || text.trim().isEmpty) return;
    final token = ++_speakToken;
    try {
      final tts = _tts;
      if (tts == null) return;
      await tts.stop();
      if (token != _speakToken) return;
      await tts.speak(text);
    } catch (error) {
      debugPrint('TTS speak failed: $error');
    }
  }

  Future<void> stopSpeaking() async {
    _speakToken++;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stopSpeaking();
    await stopAmbience();
    for (final player in _pool) {
      await player.dispose();
    }
    await _ambience.dispose();
  }
}
