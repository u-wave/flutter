import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Keeps track of the difference between the server time and the local time.
class _TimeSynchronizer {
  /// The reference server time.
  DateTime _referenceServerTime;
  /// The local time, at the previous moment when the reference server time was updated.
  DateTime _referenceLocalTime;
  Duration _offset;

  /// Get the current (estimated) server time.
  DateTime get serverTime => toServer(DateTime.now());
  /// Set the server time.
  set serverTime(DateTime time) => _setServerTime(time);

  /// Calculate the difference between server and local time.
  void _setServerTime(DateTime time) {
    _referenceLocalTime = DateTime.now();
    _referenceServerTime = time;
    _offset = _referenceLocalTime.difference(_referenceServerTime);
    print('Update server time, offset is $_offset');
  }

  /// Turn a server timestamp into a local one.
  DateTime toLocal(DateTime serverTime) => serverTime.add(_offset);
  /// Turn a local timestamp into a server one.
  DateTime toServer(DateTime localTime) => localTime.subtract(_offset);
}

/// A message from the WebSocket connection.
class _SocketMessage {
  final String command;
  final dynamic data;

  _SocketMessage({this.command, this.data});

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'data': data,
    };
  }

  factory _SocketMessage.fromJson(Map<String, dynamic> json) {
    return _SocketMessage(
      command: json['command'],
      data: json['data'],
    );
  }
}

/// Represents an incoming chat message.
class ChatMessage {
  /// Unique ID for this chat message.
  final String id;
  /// The User that sent this message.
  final User user;
  /// The contents of this message.
  final String message;
  /// The (local) time at which this message was sent.
  final DateTime timestamp;

  ChatMessage({this.id, this.user, this.message, this.timestamp});

  factory ChatMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users, _TimeSynchronizer serverTime}) {
    return ChatMessage(
      id: json['id'],
      user: users != null ? users[json['userID']] : null,
      message: json['message'],
      timestamp: serverTime.toLocal(
          DateTime.fromMillisecondsSinceEpoch(json['timestamp'])),
    );
  }
}

/// Represents an advance event.
class AdvanceMessage {
  /// The new history entry, may be null.
  final HistoryEntry entry;

  AdvanceMessage({this.entry});

  factory AdvanceMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users, _TimeSynchronizer serverTime}) {
    if (json == null) {
      return AdvanceMessage(entry: null);
    }

    final entry = HistoryEntry(
      id: json['historyID'],
      userID: json['userID'],
      user: users != null ? users[json['userID']] : null,
      media: Media.fromJson(json['media']['media']),
      artist: json['media']['artist'],
      title: json['media']['title'],
      start: json['media']['start'],
      end: json['media']['end'],
      timestamp: serverTime.toLocal(
          DateTime.fromMillisecondsSinceEpoch(json['playedAt'])),
    );
    return AdvanceMessage(entry: entry);
  }
}

class UserJoinMessage {
  final User user;

  UserJoinMessage({this.user});

  factory UserJoinMessage.fromJson(Map<String, dynamic> json) {
    final user = User.fromJson(json);
    return UserJoinMessage(user: user);
  }
}

class UserLeaveMessage {
  final String id;
  final User user;

  UserLeaveMessage({this.id, this.user});

  factory UserLeaveMessage.fromJson(dynamic json, {Map<String, User> users}) {
    final String id = json;
    final user = users != null ? users[id] : null;
    return UserLeaveMessage(id: id, user: user);
  }
}

// TODO make this able to be stored in the device's keychain
class UwaveCredentials {
  final String email;
  final String password;
  final String token;

  bool get hasToken => token != null;
  bool get hasLocalCredentials => email != null && password != null;

  UwaveCredentials({
    this.email,
    this.password,
    this.token,
  });

  String serialize() {
    return json.encode({
      'email': email,
      'password': password,
      'token': token,
    });
  }

  factory UwaveCredentials.deserialize(String serialized) {
    final creds = Map<String, String>.from(json.decode(serialized));
    return UwaveCredentials(
      email: creds['email'],
      password: creds['password'],
      token: creds['token'],
    );
  }
}

class UwaveClient {
  final String apiUrl;
  final String socketUrl;
  final _TimeSynchronizer _serverTime = _TimeSynchronizer();
  final http.Client _client = http.Client();
  final WebSocketChannel _channel;
  final StreamController<ChatMessage> _chatMessagesController =
      StreamController.broadcast();
  final StreamController<HistoryEntry> _advanceController =
      StreamController.broadcast();
  final StreamController<dynamic> _eventsController =
      StreamController.broadcast();

  UwaveCredentials _activeCredentials;
  User _loggedInUser;

  Stream<ChatMessage> get chatMessages => _chatMessagesController.stream;
  Stream<HistoryEntry> get advanceMessages => _advanceController.stream;
  Stream<dynamic> get events => _eventsController.stream;
  User get currentUser => _loggedInUser;

  final Map<String, User> _knownUsers = Map();

  UwaveClient({this.apiUrl, socketUrl})
      : _channel = IOWebSocketChannel.connect(socketUrl),
        socketUrl = socketUrl;

  Future<UwaveNowState> init({UwaveCredentials credentials}) async {
    if (credentials == null) credentials = _activeCredentials;

    _channel.stream.listen((message) {
      if (message == "-") return;
      final decoded = json.decode(message);
      this._onMessage(_SocketMessage.fromJson(decoded));
    });

    final headers = <String, String>{
      'accept': 'application/json',
    };
    if (credentials != null && credentials.hasToken) {
      headers['authorization'] = 'JWT ${credentials.token}';
      _activeCredentials = credentials;
    }

    final response = await _client.get('$apiUrl/now', headers: headers);
    final nowJson = json.decode(response.body);
    final state = UwaveNowState.fromJson(nowJson);

    _serverTime.serverTime = state.serverTime;

    state.users.forEach((id, user) {
      _knownUsers[user.id] = user;
    });

    if (state.currentEntry != null) {
      _advanceController.add(state.currentEntry);
    }

    if (state.currentUser != null) {
      _loggedInUser = state.currentUser;
    }
    if (nowJson['socketToken'] is String) {
      _sendSocketToken(nowJson['socketToken']);
    }

    if (credentials != null && !credentials.hasToken) {
      await signIn(
        email: credentials.email,
        password: credentials.password,
      );
    }

    return state;
  }

  void _sendSocketToken(String socketToken) {
    _channel.sink.add(socketToken);
  }

  Future<Null> _authenticateSocket() async {
    if (_activeCredentials == null || !_activeCredentials.hasToken) {
      throw 'Cannot authenticate to socket: no active session';
    }

    final response = await _client.get('$apiUrl/auth/socket',
      headers: {
        'accept': 'application/json',
        'authorization': 'JWT ${_activeCredentials.token}',
      },
    );
    final socketJson = json.decode(response.body);
    final socketToken = socketJson['data']['socketToken'];

    if (socketToken is String) {
      _sendSocketToken(socketToken);
    } else {
      throw 'Cannot authenticate to socket: no token found';
    }
  }

  void sendChatMessage(String text) {
    final message = json.encode(_SocketMessage(
      command: 'sendChat',
      data: text,
    ).toJson());
    _channel.sink.add(message);
  }

  Future<UwaveCredentials> signIn({String email, String password}) async {
    final response = await _client.post('$apiUrl/auth/login',
      body: json.encode({'email': email, 'password': password}),
      headers: {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw 'Sign in failed';
    }

    final authJson = json.decode(response.body);
    _activeCredentials = UwaveCredentials(
      token: authJson['meta']['jwt'],
    );
    _loggedInUser = User.fromJson(authJson['data']);

    _authenticateSocket();

    return _activeCredentials;
  }

  void _onMessage(message) {
    if (message.command == 'chatMessage') {
      final chat = ChatMessage.fromJson(message.data, users: _knownUsers, serverTime: _serverTime);
      this._chatMessagesController.add(chat);
    } else if (message.command == 'advance') {
      final advance = AdvanceMessage.fromJson(message.data, users: _knownUsers, serverTime: _serverTime);
      this._advanceController.add(advance.entry);
    } else if (message.command == 'join') {
      final join = UserJoinMessage.fromJson(message.data);
      this._knownUsers[join.user.id] = join.user;
      this._eventsController.add(join);
    } else if (message.command == 'leave') {
      final leave = UserLeaveMessage.fromJson(message.data, users: _knownUsers);
      // this._knownUsers.remove(leave.id);
      this._eventsController.add(leave);
    }
  }

  void dispose() {
    _advanceController.close();
    _chatMessagesController.close();
    _eventsController.close();
    _client.close();
    if (_channel != null) {
      _channel.sink.close(ws_status.goingAway);
    }
  }
}

class UwaveNowState {
  final String motd;
  final Map<String, User> users;
  final User currentUser;
  final HistoryEntry currentEntry;
  final List<String> waitlist;
  final DateTime serverTime;

  UwaveNowState({
    this.motd,
    this.users,
    this.currentUser,
    this.currentEntry,
    this.waitlist,
    this.serverTime,
  });

  factory UwaveNowState.fromJson(Map<String, dynamic> json) {
    final Map<String, User> users = {};

    json['users']
      .map<User>((u) => User.fromJson(u))
      .forEach((user) {
        users[user.id] = user;
      });

    final serverTime = DateTime.fromMillisecondsSinceEpoch(json['time']);
    final tempSyncher = _TimeSynchronizer();
    tempSyncher.serverTime = serverTime;

    return UwaveNowState(
      motd: json['motd'],
      users: users,
      currentUser: json['user'] != null
        ? User.fromJson(json['user'])
        : null,
      currentEntry: json['booth'] != null
        ? HistoryEntry.fromJson(json['booth'], users: users, serverTime: tempSyncher)
        : null,
      waitlist: json['waitlist'].cast<String>().toList(),
      serverTime: serverTime,
    );
  }
}

class User {
  final String id;
  String username;
  String avatarUrl;
  List<String> roles;

  User({this.id, this.username, this.avatarUrl, this.roles});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      username: json['username'],
      avatarUrl: json['avatar'],
      roles: json['roles'].cast<String>(),
    );
  }
}

class Media {
  final String id;
  final String sourceType;
  final String sourceID;
  final String thumbnailUrl;
  String artist;
  String title;
  int duration;
  Map<String, dynamic> sourceData;

  Media(
      {this.id,
      this.sourceType,
      this.sourceID,
      this.artist,
      this.title,
      this.thumbnailUrl,
      this.duration,
      this.sourceData});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['_id'],
      sourceType: json['sourceType'],
      sourceID: json['sourceID'],
      artist: json['artist'],
      title: json['title'],
      thumbnailUrl: json['thumbnail'],
      duration: json['duration'],
      sourceData: json['sourceData'],
    );
  }
}

class PlaylistItem {
  final String id;
  final Media media;
  String artist;
  String title;
  int start;
  int end;

  PlaylistItem(
      {this.id, this.media, this.artist, this.title, this.start, this.end});

  factory PlaylistItem.fromJson(Map<String, dynamic> json, {Map<String, Media> medias}) {
    return PlaylistItem(
      id: json['_id'],
      media: json['media'] is String
        ? (medias != null ? medias[json['media']] : null)
        : Media.fromJson(json['media']),
      artist: json['artist'],
      title: json['title'],
      start: json['start'],
      end: json['end'],
    );
  }
}

class Playlist {
  final String id;
  String name;
  int size;

  Playlist({this.id, this.name, this.size});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['_id'],
      name: json['name'],
      size: json['size'],
    );
  }
}

class HistoryEntry {
  final String id;
  final String userID;
  final User user;
  final Media media;
  final String artist;
  final String title;
  final int start;
  final int end;
  final DateTime timestamp;

  HistoryEntry(
      {this.id, this.userID, this.user, this.media, this.artist, this.title, this.start, this.end, this.timestamp});

  factory HistoryEntry.fromJson(Map<String, dynamic> json, {Map<String, Media> medias, Map<String, User> users, _TimeSynchronizer serverTime}) {
    return HistoryEntry(
      id: json['_id'],
      userID: json['user'],
      user: users != null ? users[json['user']] : null,
      media: json['media']['media'] is String
        ? (medias != null ? medias[json['media']['media']] : null)
        : Media.fromJson(json['media']['media']),
      artist: json['media']['artist'],
      title: json['media']['title'],
      start: json['media']['start'],
      end: json['media']['end'],
      timestamp: serverTime.toLocal(json['playedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['playedAt'])
          : DateTime.parse(json['playedAt'])),
    );
  }
}
