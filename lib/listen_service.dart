import 'package:flutter/services.dart' show MethodChannel;

const _channel = MethodChannel('u-wave.net/background');

class ListenService {
  const ListenService._();

  static ListenService _instance;
  static ListenService getInstance() {
    _instance ??= const ListenService._();
    return _instance;
  }

  Future<void> foreground() async {
    await _channel.invokeMethod('foreground', null);
  }

  Future<void> background() async {
    await _channel.invokeMethod('background', null);
  }

  Future<void> exit() async {
    await _channel.invokeMethod('exit', null);
  }
}
