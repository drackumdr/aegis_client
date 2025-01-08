import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Timer? _pauseTimer;
  bool isPaused = false; // Changed from _isPaused to isPaused

  factory AudioManager() {
    return _instance;
  }

  AudioManager._internal();

  Future<void> playAlertSound() async {
    if (_isPlaying || isPaused) return; // Updated reference

    try {
      _isPlaying = true;
      await _player.play(AssetSource('alert.wav'));
      await Future.delayed(const Duration(seconds: 2));
      if (!isPaused) {
        // Updated reference
        _isPlaying = false;
      }
    } catch (e) {
      _isPlaying = false;
      isPaused = false; // Updated reference
    }
  }

  void pauseSound(Duration duration) {
    isPaused = true; // Updated reference
    _player.stop();
    _pauseTimer?.cancel();
    _pauseTimer = Timer(duration, () {
      isPaused = false; // Updated reference
      _isPlaying = false;
    });
  }

  void dispose() {
    _pauseTimer?.cancel();
    _player.dispose();
  }
}
