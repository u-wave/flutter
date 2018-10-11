import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import './u_wave/u_wave.dart' show HistoryEntry;
import './settings.dart' show PlaybackType;

/// Download a URL's contents to a string.
///
/// This is called by the NewPipe extractor, so I don't have to learn and
/// ship a Java HTTP client but can instead use the Dart one :P
Future<String> _download(Map<String, String> headers) async {
  final url = headers.remove('_url');
  final response = await http.get(url, headers: headers);
  if (response.statusCode != 200) {
    throw 'Unexpected response ${response.statusCode} from $url';
  }
  headers['_url'] = url; // restore
  return response.body;
}

final _channel = MethodChannel('u-wave.net/player')
  ..setMethodCallHandler((methodCall) async {
    switch (methodCall.method) {
      case 'download':
        return await _download(Map<String, String>.from(methodCall.arguments));
      default:
        throw MissingPluginException('Unknown method ${methodCall.method}');
    }
  });

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
  ProgressTimer({this.startTime}) {
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

class Player {
  Player._();

  static Player _instance;
  static Player getInstance() {
    if (_instance == null) {
      _instance = Player._();
    }
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

    print('Playing entry ${entry.media.artist} - ${entry.media.title} from $seekInMedia');

    final Map<dynamic, dynamic> result = await _channel.invokeMethod('play', <String, String>{
      'sourceType': entry.media.sourceType,
      'sourceID': entry.media.sourceID,
      'seek': '${seekInMedia.isNegative ? 0 : seekInMedia.inMilliseconds}',
      'playbackType': '${playbackType.index}',
    });

    final int texture = result['texture'];
    final double aspectRatio = result['aspectRatio'];

    _progressTimer = ProgressTimer(startTime: entry.timestamp);
    return PlaybackSettings(
      texture: texture,
      aspectRatio: aspectRatio,
      onProgress: _progressTimer,
    );
  }

  Future<Null> setPlaybackType(PlaybackType playbackType) async {
    await _channel.invokeMethod('setPlaybackType', playbackType.index);
  }

  void stop() {
    if (_progressTimer != null) {
      _progressTimer.cancel();
      _progressTimer = null;
    }
    _channel.invokeMethod('play', null);
  }
}
