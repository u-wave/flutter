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

class VoteStats {
  final List<User> upvoters = [];
  final List<User> downvoters = [];
  final List<User> favoriters = [];

  void addUpvote(User user) {
    // remove() is safe to call when it's not in the list, too.
    downvoters.remove(user);
    upvoters.add(user);
  }

  void addDownvote(User user) {
    // remove() is safe to call when it's not in the list, too.
    upvoters.remove(user);
    downvoters.add(user);
  }

  void addFavorite(User user) {
    favoriters.add(user);
  }

  bool didUpvote(User user) {
    return upvoters.any((voter) => voter.id == user.id);
  }

  bool didDownvote(User user) {
    return downvoters.any((voter) => voter.id == user.id);
  }

  bool didFavorite(User user) {
    return favoriters.any((voter) => voter.id == user.id);
  }
}

class ListenStore {
  final _storage = FlutterSecureStorage();
  Settings _settings;
  UwaveServer _server;
  UwaveClient _client;
  HistoryEntry _playing;
  PlaybackType _playbackType = PlaybackType.disabled;
  PlaybackSettings _playbackSettings;
  VoteStats _voteStats;
  Connectivity _connectivity;
  ConnectivityResult _connectivityStatus = ConnectivityResult.none;
  StreamSubscription<HistoryEntry> _advanceSubscription;
  StreamSubscription<ConnectivityResult> _connectivitySubscription;
  StreamSubscription<ChatMessage> _chatSubscription;
  StreamSubscription<dynamic> _eventsSubscription;
  StreamSubscription<SettingUpdate> _settingsSubscription;
  StreamSubscription<String> _notificationSubscription;

  StreamController<Null> _update = StreamController.broadcast();
  Stream<Null> get onUpdate => _update.stream;

  List<dynamic> chatHistory = [];

  bool get isPlaying => _playing != null;
  HistoryEntry get currentEntry => _playing;
  PlaybackSettings get playbackSettings => _playbackSettings;
  VoteStats get voteStats => _voteStats;
  bool get isSignedIn => _client.currentUser != null;
  User get currentUser => _client.currentUser;
  UwaveServer get server => _server;
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

    final notification = NowPlayingNotification.getInstance();
    _notificationSubscription = notification.onIntent.listen((action) {
      switch (action) {
        case 'net.u_wave.android.UPVOTE':
          _client?.upvote();
          break;
        case 'net.u_wave.android.DOWNVOTE':
          _client?.downvote();
          break;
        case 'net.u_wave.android.MUTE_UNMUTE':
          // TODO override playbackType by PlaybackType.none
          break;
        case 'net.u_wave.android.DISCONNECT':
          disconnect();
          break;
      }
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
      } else if (message is VoteMessage) {
        if (message.isUpvote) {
          _voteStats.addUpvote(message.user);
        } else if (message.isDownvote) {
          _voteStats.addDownvote(message.user);
        }

        if (_client.currentUser != null && message.user.id == _client.currentUser.id) {
          NowPlayingNotification.getInstance()
              ..setVote(message.direction);
        }

        _emitUpdate();
      } else if (message is FavoriteMessage) {
        _voteStats.addFavorite(message.user);
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

    stop();

    _connectivitySubscription.cancel();
    _advanceSubscription.cancel();
    _eventsSubscription.cancel();
    _chatSubscription.cancel();
    _settingsSubscription.cancel();
    _notificationSubscription.cancel();
    _client.dispose();

    _connectivitySubscription = null;
    _advanceSubscription = null;
    _eventsSubscription = null;
    _chatSubscription = null;
    _settingsSubscription = null;
    _notificationSubscription = null;

    chatHistory.clear();

    _server = null;

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

    if (_playing != null) {
      Player.getInstance()
          ..setPlaybackType(playbackType);
    }

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

    _voteStats = VoteStats();
    _playing = entry;
    _playbackSettings = playbackSettings;
    _emitUpdate();

    print('entry.user ${entry.user}');
    notification.show(
      artist: entry.artist,
      title: entry.title,
      duration: entry.end - entry.start,
      progress: playbackSettings.onProgress,
      isCurrentUser: entry.user != null && entry.user.id == _client.currentUser?.id,
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
