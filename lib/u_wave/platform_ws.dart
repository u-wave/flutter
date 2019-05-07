import 'dart:async' show Future, Stream, EventSink;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import './ws.dart' show WebSocket;

const _eventChannel = EventChannel('u-wave.net/websocket-events');
const _methodChannel = MethodChannel('u-wave.net/websocket');

const _NO_MESSAGE = <String>[];

class PlatformWebSocket extends WebSocket {
  final String _socketUrl;
  Stream<dynamic> _stream;

  @override
  Stream<String> get stream =>
      _stream.expand((dynamic message) {
        if (message is String) {
          debugPrint('[PlatformWebSocket] $message');
          if (message == '+open') return _NO_MESSAGE;
          if (message == '+close') return _NO_MESSAGE;
          return [message];
        }
        return _NO_MESSAGE;
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
    _methodChannel.invokeMethod<void>('send', event);
  }
  @override
  void close() {
    _methodChannel.invokeMethod<void>('close', null);
  }
  @override
  void addError(Object error, [StackTrace stackTrace]) {
    throw '_PlatformWebSocketSink#addError is not implemented';
  }
}
