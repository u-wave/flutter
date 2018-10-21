import 'dart:async' show Future, Stream, EventSink;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import './ws.dart' show WebSocket;

final _eventChannel = EventChannel('u-wave.net/websocket');
final _methodChannel = MethodChannel('u-wave.net/websocket');

class PlatformWebSocket extends WebSocket {
  final String _socketUrl;
  Stream<dynamic> _stream;

  Stream<String> get stream =>
      _stream.expand((message) {
        debugPrint('[PlatformWebSocket] $message');
        if (message == '+open') return <String>[];
        if (message == '+close') return <String>[];
        return [message];
      });
  EventSink get sink => _PlatformWebSocketSink();

  PlatformWebSocket(String socketUrl)
      : assert(socketUrl != null),
        _socketUrl = socketUrl {
    _stream = _eventChannel.receiveBroadcastStream(_socketUrl);
  }

  void init() {}

  Future<Null> reconnect() async {}
}

class _PlatformWebSocketSink extends EventSink<String> {
  void add(String event) {
    _methodChannel.invokeMethod('send', event);
  }
  void close() {
    _methodChannel.invokeMethod('close', null);
  }
  void addError(Object error, [StackTrace stackTrace]) {
    throw '_PlatformWebSocketSink#addError is not implemented';
  }
}
