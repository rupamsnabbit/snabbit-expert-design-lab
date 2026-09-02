import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// Manages deterrence audio playback during SoS.
class ShieldDeterrenceAudio {
  Timer? _timer;
  final AudioPlayer _player = AudioPlayer();

  /// Starts the deterrence audio after [delaySecs].
  ///
  /// [isActive] is checked when the timer fires to avoid playing if SoS was
  /// cancelled in the meantime. [onPlayed] is called after successful playback.
  void start({
    required int delaySecs,
    required bool Function() isActive,
    VoidCallback? onPlayed,
  }) {
    cancel();
    _timer = Timer(Duration(seconds: delaySecs), () async {
      if (!isActive()) return;
      try {
        await FlutterVolumeController.setVolume(1.0);
        await _player.play(
          AssetSource('audio/shield_deterrence.mp3'),
          ctx: AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.duckOthers},
            ),
          ),
        );
        onPlayed?.call();
      } catch (_) {}
    });
  }

  /// Cancels the pending timer and stops any playing audio.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _player.stop();
  }

  /// Disposes the audio player.
  void dispose() {
    cancel();
    _player.dispose();
  }
}
