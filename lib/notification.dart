import 'dart:async';
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException;
import './player.dart' show ProgressTimer;

const _channel = MethodChannel('u-wave.net/notification');

class NowPlayingNotification {
  NowPlayingNotification._() {
    _channel.setMethodCallHandler((methodCall) async {
      switch (methodCall.method) {
        case 'intent':
          _intents.add(methodCall.arguments as String);
          break;
        default:
          throw MissingPluginException('Unknown method ${methodCall.method}');
      }
    });
  }

  StreamSubscription<Duration> _progressSubscription;
  final StreamController<String> _intents = StreamController.broadcast();
  Stream<String> get onIntent => _intents.stream;

  static NowPlayingNotification _instance;
  static NowPlayingNotification getInstance() {
    _instance ??= NowPlayingNotification._();
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
    bool showVoteButtons = false,
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
      'showVoteButtons': showVoteButtons ? 'true' : 'false',
    });

    _progressSubscription = progress.stream.listen((past) {
      _setProgress(past.inSeconds, duration);
    });
  }

  void setVote(int direction) {
    assert(direction == -1 || direction == 1);
    _channel.invokeMethod('setVote', direction);
  }

  void close() {
    _channel.invokeMethod('nowPlaying', null);
  }
}
