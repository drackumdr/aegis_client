import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  factory AudioManager() {
    return _instance;
  }

  AudioManager._internal();

  Future<void> playAlertSound() async {
    if (_isPlaying) return;

    try {
      _isPlaying = true;
      await _player.play(AssetSource('alert.wav'));
      await Future.delayed(const Duration(seconds: 2));
      _isPlaying = false;
    } catch (e) {
      _isPlaying = false;
    }
  }

  void dispose() {
    _player.dispose();
  }
}
