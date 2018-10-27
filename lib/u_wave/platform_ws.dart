import 'dart:async' show Future, Stream, EventSink;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import './ws.dart' show WebSocket;

const _eventChannel = EventChannel('u-wave.net/websocket-events');
const _methodChannel = MethodChannel('u-wave.net/websocket');

class PlatformWebSocket extends WebSocket {
  final String _socketUrl;
  Stream<dynamic> _stream;

  @override
  Stream<String> get stream =>
      _stream.expand((message) {
        debugPrint('[PlatformWebSocket] $message');
        if (message == '+open') return <String>[];
        if (message == '+close') return <String>[];
        return [message as String];
      });
  @override
  EventSink get sink => _PlatformWebSocketSink();

  PlatformWebSocket(String socketUrl)
      : assert(socketUrl != null),
        _socketUrl = socketUrl {
    _stream = _eventChannel.receiveBroadcastStream(_socketUrl);
  }

  @override
  void init() {}

  @override
  Future<void> reconnect() async {}
}

class _PlatformWebSocketSink extends EventSink<String> {
  @override
  void add(String event) {
    _methodChannel.invokeMethod('send', event);
  }
  @override
  void close() {
    _methodChannel.invokeMethod('close', null);
  }
  @override
  void addError(Object error, [StackTrace stackTrace]) {
    throw '_PlatformWebSocketSink#addError is not implemented';
  }
}
