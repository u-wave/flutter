import 'dart:async';
import 'package:flutter/services.dart' show MethodChannel;
import './player.dart' show ProgressTimer;

const _channel = MethodChannel('u-wave.net/notification');

class NowPlayingNotification {
  NowPlayingNotification._();

  StreamSubscription<Duration> _progressSubscription;

  static NowPlayingNotification _instance;
  static NowPlayingNotification getInstance() {
    if (_instance == null) {
      _instance = NowPlayingNotification._();
    }
    return _instance;
  }

  void _setProgress(int progress, int duration) {
    _channel.invokeMethod('setProgress', [progress, duration]);
  }

  void show({
    String artist,
    String title,
    int duration,
    ProgressTimer progress,
  }) {
    if (_progressSubscription != null) {
      _progressSubscription.cancel();
      _progressSubscription = null;
    }

    _channel.invokeMethod('nowPlaying', <String, String>{
      'artist': artist,
      'title': title,
      'duration': '$duration',
      'seek': '${progress.current.inSeconds}',
    });

    _progressSubscription = progress.stream.listen((past) {
      _setProgress(past.inSeconds, duration);
    });
  }

  void close() {
    _channel.invokeMethod('nowPlaying', null);
  }
}
