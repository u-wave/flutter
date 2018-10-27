import 'dart:async' show Future, Timer, Stream, EventSink;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import './ws.dart' show WebSocket;

const _NO_MESSAGE = <String>[];

typedef ReconnectCallback = Future<void> Function();
class DartWebSocket extends WebSocket {
  final String _socketUrl;
  WebSocketChannel _channel;
  Timer _disconnectTimer;
  ReconnectCallback _customReconnect;

  @override
  Stream<String> get stream =>
      _channel.stream.expand((dynamic message) {
        _restartDisconnectTimer();
        if (message is String) {
          if (message == '-') return _NO_MESSAGE;
          return [message];
        }
        return _NO_MESSAGE;
      });
  @override
  EventSink get sink => _channel.sink;

  DartWebSocket(String socketUrl, {ReconnectCallback reconnect})
      : assert(socketUrl != null),
        _channel = IOWebSocketChannel.connect(socketUrl),
        _socketUrl = socketUrl,
        _customReconnect = reconnect;

  void _restartDisconnectTimer() {
    if (_disconnectTimer != null) _disconnectTimer.cancel();
    _disconnectTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('Socket timed out ... reconnecting');
      _doReconnect().catchError((dynamic err) {
        debugPrint('Failed to reconnect: $err');
        // TODO retry
      });
    });
  }

  @override
  void init() {
    _restartDisconnectTimer();
  }

  Future<void> _doReconnect() {
    if (_customReconnect != null) return _customReconnect();
    return reconnect();
  }

  @override
  Future<void> reconnect() async {
    _channel.sink.close(ws_status.goingAway);
    _channel = IOWebSocketChannel.connect(_socketUrl);
  }
}
