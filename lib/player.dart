import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import './u_wave/u_wave.dart' show HistoryEntry;
import './settings.dart' show Settings;

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
      case 'setAspectRatio':
        Player.getInstance()
            .setAspectRatio(methodCall.arguments.toDouble());
        return null;
      default:
        throw MissingPluginException('Unknown method ${methodCall.method}');
    }
  });

class PlaybackSettings {
  final int texture;
  final double aspectRatio;

  bool get hasTexture => texture != null;

  PlaybackSettings({this.texture, this.aspectRatio});
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

  Stream<Duration> _currentProgress;
  Stream<Duration> get progress => _currentProgress;
  StreamController<double> _aspectRatio = StreamController.broadcast();
  Stream<double> get onAspectRatio => _aspectRatio.stream;

  Future<PlaybackSettings> play(HistoryEntry entry, Settings settings) async {
    final seek = DateTime.now().difference(entry.timestamp);
    final duration = Duration(seconds: entry.end - entry.start);
    final seekInMedia = seek + Duration(seconds: entry.start);

    print('Playing entry ${entry.media.artist} - ${entry.media.title} from $seekInMedia');

    _currentProgress = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now().difference(entry.timestamp),
    )
      .asBroadcastStream()
      .take(duration.inSeconds - seek.inSeconds);

    final texture = await _channel.invokeMethod('play', <String, String>{
      'sourceType': entry.media.sourceType,
      'sourceID': entry.media.sourceID,
      'seek': '${seekInMedia.isNegative ? 0 : seekInMedia.inMilliseconds}',
      'playbackType': '${settings.playbackType.index}',
    });

    // TODO return texture + aspect ratio from channel

    return PlaybackSettings(
      texture: texture,
      aspectRatio: 16 / 9,
    );
  }

  void stop() {
    _channel.invokeMethod('play', null);
  }

  void setAspectRatio(double newAspectRatio) {
    _aspectRatio.add(newAspectRatio);
  }
}
