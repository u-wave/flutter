import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import './u_wave/u_wave.dart' show HistoryEntry, Media;
import './settings.dart' show PlaybackType;

final _channel = const MethodChannel('u-wave.net/player')
  ..setMethodCallHandler((methodCall) async {
    switch (methodCall.method) {
      default:
        throw MissingPluginException('Unknown method ${methodCall.method}');
    }
  });

bool _isAudioOnlySourceType(String sourceType) {
  return sourceType == 'soundcloud';
}

class PlaybackSettings {
  final int texture;
  final double aspectRatio;
  final ProgressTimer onProgress;

  bool get hasTexture => texture != null;

  PlaybackSettings({this.texture, this.aspectRatio, this.onProgress});
}

class ProgressTimer {
  Timer _timer;
  StreamController<Duration> _controller;
  Stream<Duration> get stream => _controller.stream;
  Duration get current => DateTime.now().difference(startTime);

  DateTime startTime;
  ProgressTimer({this.startTime}) : assert(startTime != null) {
    _controller = StreamController.broadcast(
      onListen: _startTimer,
      onCancel: _stopTimer,
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), _update);
    _update(_timer);
  }

  void _stopTimer() {
    _timer.cancel();
  }

  void _update(Timer _) {
    _controller.add(current);
  }

  void cancel() {
    _controller.close();
  }
}

String _getNewPipeSourceName(String sourceType) {
  if (sourceType == 'youtube') return 'YouTube';
  if (sourceType == 'soundcloud') return 'SoundCloud';
  return null;
}

String _getNewPipeSourceURL(Media media) {
  assert(media != null);
  if (media.sourceType == 'youtube') {
    return 'https://youtube.com/watch?v=${media.sourceID}';
  }
  if (media.sourceType == 'soundcloud') {
    return media.sourceData['permalinkUrl'] as String ?? 'https://api.soundcloud.com/tracks/${media.sourceID}';
  }
  return null;
}

class Player {
  Player._();

  static Player _instance;
  static Player getInstance() {
    _instance ??= Player._();
    return _instance;
  }

  ProgressTimer _progressTimer;

  Future<PlaybackSettings> play(HistoryEntry entry, PlaybackType playbackType) async {
    if (_progressTimer != null) {
      _progressTimer.cancel();
      _progressTimer = null;
    }

    final seek = DateTime.now().difference(entry.timestamp);
    final seekInMedia = seek + Duration(seconds: entry.start);

    debugPrint('Playing entry ${entry.media.artist} - ${entry.media.title} from $seekInMedia');

    final npType = _getNewPipeSourceName(entry.media.sourceType);
    final npUrl = _getNewPipeSourceURL(entry.media);

    if (playbackType == PlaybackType.both &&
        _isAudioOnlySourceType(entry.media.sourceType)) {
      playbackType = PlaybackType.audioOnly;
    }

    final Map<dynamic, dynamic> result = await _channel.invokeMethod('play', <String, String>{
      'sourceName': npType,
      'sourceUrl': npUrl,
      'seek': '${seekInMedia.isNegative ? 0 : seekInMedia.inMilliseconds}',
      'playbackType': '${playbackType.index}',
    });

    final texture = result['texture'] as int;
    final aspectRatio = result['aspectRatio'] as double;

    _progressTimer = ProgressTimer(startTime: entry.timestamp);
    return PlaybackSettings(
      texture: texture,
      aspectRatio: aspectRatio,
      onProgress: _progressTimer,
    );
  }

  Future<void> setPlaybackType(PlaybackType playbackType) async {
    await _channel.invokeMethod<void>('setPlaybackType', playbackType.index);
  }

  void stop() {
    if (_progressTimer != null) {
      _progressTimer.cancel();
      _progressTimer = null;
    }
    _channel.invokeMethod<void>('play', null);
  }
}
