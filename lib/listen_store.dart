import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import 'package:connectivity/connectivity.dart' show Connectivity, ConnectivityResult;
import './u_wave/announce.dart' show UwaveServer;
import './u_wave/u_wave.dart';
import './settings.dart' show Settings, SettingUpdate, PlaybackType;
import './notification.dart' show NowPlayingNotification;
import './player.dart' show Player, PlaybackSettings;

bool _isChatVisibleEvent(message) {
  return message is UserJoinMessage ||
      message is UserLeaveMessage;
}

void _log(String input) {
  debugPrint('[ListenStore] $input');
}

class ListenStore {
  final _storage = FlutterSecureStorage();
  Settings _settings;
  UwaveServer _server;
  UwaveClient _client;
  HistoryEntry _playing;
  PlaybackType _playbackType = PlaybackType.disabled;
  PlaybackSettings _playbackSettings;
  Connectivity _connectivity;
  ConnectivityResult _connectivityStatus = ConnectivityResult.none;
  StreamSubscription<HistoryEntry> _advanceSubscription;
  StreamSubscription<ConnectivityResult> _connectivitySubscription;
  StreamSubscription<ChatMessage> _chatSubscription;
  StreamSubscription<dynamic> _eventsSubscription;
  StreamSubscription<SettingUpdate> _settingsSubscription;

  StreamController<Null> _update = StreamController.broadcast();
  Stream<Null> get onUpdate => _update.stream;

  List<dynamic> chatHistory = [];

  bool get isPlaying => _playing != null;
  HistoryEntry get currentEntry => _playing;
  PlaybackSettings get playbackSettings => _playbackSettings;
  bool get isSignedIn => _client.currentUser != null;
  User get currentUser => _client.currentUser;
  UwaveClient get uwaveClient => _client;

  ListenStore({Settings settings}) : assert(settings != null) {
    _settings = settings;
  }

  void _emitUpdate() => _update.add(null);

  /// Connect to a server.
  ///
  /// This tries to authenticate with saved credentials, and starts playback.
  Future<Null> connect(UwaveServer server) async {
    if (_server == server) {
      // Connecting to the current server doesn't do anything.
      return;
    }

    disconnect();

    _server = server;
    _client = UwaveClient(
      apiUrl: _server.apiUrl,
      socketUrl: _server.socketUrl,
    );

    _connectivity = Connectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (_connectivityStatus == result) {
        return; // no need to update
      }

      _connectivityStatus = result;
      _onUpdatePlaybackType();
    });

    _settingsSubscription = _settings.onUpdate.listen((update) {
      if (update.name == 'playbackType' || update.name == 'playbackTypeData') {
        _onUpdatePlaybackType();
      }
    });

    _advanceSubscription = _client.advanceMessages.listen((entry) {
      if (entry != null) {
        play(entry);
      } else {
        stop();
      }
    });

    _chatSubscription = _client.chatMessages.listen((message) {
      chatHistory.add(message);
      _emitUpdate();
    });

    _eventsSubscription = _client.events.listen((message) {
      if (_isChatVisibleEvent(message)) {
        chatHistory.add(message);
        _emitUpdate();
      }
    });

    final credentials = await loadCredentials();
    await _client.init(credentials: credentials);

    _emitUpdate();
  }

  /// Disconnect from a server, stopping playback.
  void disconnect() {
    if (_server == null) return;

    _connectivitySubscription.cancel();
    _advanceSubscription.cancel();
    _eventsSubscription.cancel();
    _chatSubscription.cancel();
    _settingsSubscription.cancel();
    _client.dispose();

    _connectivitySubscription = null;
    _advanceSubscription = null;
    _eventsSubscription = null;
    _chatSubscription = null;
    _settingsSubscription = null;

    chatHistory.clear();

    _emitUpdate();
  }

  void close() {
    disconnect();
    _update.close();
  }

  void _onUpdatePlaybackType() {
    final playbackType = _connectivityStatus == ConnectivityResult.wifi
        ? _settings.playbackType
        : _settings.playbackTypeData;

    _log('Connectivity changed, switching to $playbackType');
    Player.getInstance()
        ..setPlaybackType(playbackType);

    _playbackType = playbackType;
    _emitUpdate();
  }

  /// Start playing a history entry.
  Future<Null> play(HistoryEntry entry) async {
    final player = Player.getInstance();
    final notification = NowPlayingNotification.getInstance();
    final playbackSettings = await player.play(entry, _playbackType);

    if (playbackSettings.hasTexture) {
      _log('Using player texture #${playbackSettings.texture}');
    } else {
      _log('Audio-only: no player texture');
    }

    _playing = entry;
    _playbackSettings = playbackSettings;
    _emitUpdate();

    notification.show(
      artist: entry.artist,
      title: entry.title,
      duration: entry.end - entry.start,
      progress: playbackSettings.onProgress,
    );
  }

  /// Stop playing.
  stop() {
    _log('Stopping playback');
    Player.getInstance()
      ..stop();
    NowPlayingNotification.getInstance()
      ..close();
    _playing = null;
    _emitUpdate();
  }

  void saveCredentials(UwaveCredentials creds) async {
    assert(creds != null);
    final key = _server.publicKey;
    await _storage.write(
      key: 'credentials:$key',
      value: creds.serialize(),
    );
  }

  Future<UwaveCredentials> loadCredentials() async {
    assert(_server != null);
    final key = _server.publicKey;

    final json = await _storage.read(key: 'credentials:$key');
    return json is String
      ? UwaveCredentials.deserialize(json)
      : null;
  }

  void sendChat(String message) {
    assert(_client != null);
    _client.sendChatMessage(message);
  }
}
