import 'dart:async' show Future, Timer, Stream, EventSink;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import './ws.dart' show WebSocket;

typedef ReconnectCallback = Future<Null> Function();
class DartWebSocket extends WebSocket {
  final String _socketUrl;
  WebSocketChannel _channel;
  Timer _disconnectTimer;
  ReconnectCallback _customReconnect;

  Stream<String> get stream =>
      _channel.stream.expand((message) {
        _restartDisconnectTimer();
        if (message == '-') return <String>[];
        return [message];
      });
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
      _doReconnect().catchError((err) {
        debugPrint('Failed to reconnect: $err');
        // TODO retry
      });
    });
  }

  void init() {
    _restartDisconnectTimer();
  }

  Future<Null> _doReconnect() {
    if (_customReconnect != null) return _customReconnect();
    return reconnect();
  }

  Future<Null> reconnect() async {
    _channel.sink.close(ws_status.goingAway);
    _channel = IOWebSocketChannel.connect(_socketUrl);
  }
}
