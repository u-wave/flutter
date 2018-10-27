import 'dart:async' show Stream, EventSink;

abstract class WebSocket {
  Stream<String> get stream => const Stream.empty();
  EventSink get sink => _NullStreamSink();

  void init();
  void reconnect();
}

class _NullStreamSink extends EventSink<String> {
  void add(String event) {}
  void addError(Object error, [StackTrace stackTrace]) {}
  void close() {}
}
