import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import './ws.dart' show WebSocket;
import './dart_ws.dart' show DartWebSocket;
import './platform_ws.dart' show PlatformWebSocket;
import './markup.dart' show MarkupParser, MarkupNode;

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
    debugPrint('Update server time, offset is $_offset');
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
      command: json['command'] as String,
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

  List<MarkupNode> _parsed;
  List<MarkupNode> get parsedMessage => _getParsed();

  ChatMessage({this.id, this.user, this.message, this.timestamp});

  List<MarkupNode> _getParsed() {
    _parsed ??= MarkupParser(source: message).parse();
    return _parsed;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users, _TimeSynchronizer serverTime}) {
    return ChatMessage(
      id: json['id'] as String,
      user: users != null ? users[json['userID'] as String] : null,
      message: json['message'] as String,
      timestamp: serverTime.toLocal(
          DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)),
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
      id: json['historyID'] as String,
      userID: json['userID'] as String,
      user: users != null ? users[json['userID'] as String] : null,
      media: Media.fromJson(json['media']['media'] as Map<String, dynamic>),
      artist: json['media']['artist'] as String,
      title: json['media']['title'] as String,
      start: json['media']['start'] as int,
      end: json['media']['end'] as int,
      timestamp: serverTime.toLocal(
          DateTime.fromMillisecondsSinceEpoch(json['playedAt'] as int)),
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

class VoteMessage {
  final int direction;
  final User user;

  bool get isUpvote => direction == 1;
  bool get isDownvote => direction == -1;

  VoteMessage({this.direction, this.user});

  factory VoteMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users}) {
    return VoteMessage(
      direction: json['value'] as int,
      user: users != null ? users[json['_id'] as String] : null,
    );
  }
}

class FavoriteMessage {
  final User user;

  FavoriteMessage({this.user});

  factory FavoriteMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users}) {
    return FavoriteMessage(
      user: users != null ? users[json['userID'] as String] : null,
    );
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
    final creds = Map<String, String>.from(json.decode(serialized) as Map<String, dynamic>);
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
  WebSocket _ws;
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

  final Map<String, User> _knownUsers = {};

  UwaveClient({this.apiUrl, this.socketUrl, bool usePlatformSocket = false})
      : assert(apiUrl != null),
        assert(socketUrl != null) {
    if (usePlatformSocket) {
      _ws = PlatformWebSocket(socketUrl);
    } else {
      _ws = DartWebSocket(socketUrl, reconnect: () async {
        await reconnect();
      });
    }
  }

  void _initSocket() {
    _ws.init();
    _ws.stream.listen((message) {
      final Map<String, dynamic> decoded = json.decode(message);
      _onMessage(_SocketMessage.fromJson(decoded));
    });
  }

  Future<UwaveNowState> reconnect() async {
    _ws.reconnect();
    return await init(credentials: _activeCredentials);
  }

  Future<UwaveNowState> init({UwaveCredentials credentials}) async {
    credentials ??= _activeCredentials;

    _initSocket();

    final headers = <String, String>{
      'accept': 'application/json',
    };
    if (credentials != null && credentials.hasToken) {
      headers['authorization'] = 'JWT ${credentials.token}';
      _activeCredentials = credentials;
    }

    final response = await _client.get('$apiUrl/now', headers: headers);
    final Map<String, dynamic> nowJson = json.decode(response.body);
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
      _sendSocketToken(nowJson['socketToken'] as String);
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
    _ws.sink.add(socketToken);
  }

  Future<void> _authenticateSocket() async {
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

  void upvote() {
    final message = json.encode(_SocketMessage(
      command: 'vote',
      data: 1,
    ).toJson());
    _ws.sink.add(message);
  }

  void downvote() {
    final message = json.encode(_SocketMessage(
      command: 'vote',
      data: -1,
    ).toJson());
    _ws.sink.add(message);
  }

  void sendChatMessage(String text) {
    final message = json.encode(_SocketMessage(
      command: 'sendChat',
      data: text,
    ).toJson());
    _ws.sink.add(message);
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
      token: authJson['meta']['jwt'] as String,
    );
    _loggedInUser = User.fromJson(authJson['data'] as Map<String, dynamic>);

    _authenticateSocket();

    return _activeCredentials;
  }

  void _onMessage(message) {
    if (message.command == 'chatMessage') {
      final chat = ChatMessage.fromJson(message.data as Map<String, dynamic>, users: _knownUsers, serverTime: _serverTime);
      _chatMessagesController.add(chat);
    } else if (message.command == 'advance') {
      final advance = AdvanceMessage.fromJson(message.data as Map<String, dynamic>, users: _knownUsers, serverTime: _serverTime);
      _advanceController.add(advance.entry);
    } else if (message.command == 'join') {
      final join = UserJoinMessage.fromJson(message.data as Map<String, dynamic>);
      _knownUsers[join.user.id] = join.user;
      _eventsController.add(join);
    } else if (message.command == 'leave') {
      final leave = UserLeaveMessage.fromJson(message.data as Map<String, dynamic>, users: _knownUsers);
      // _knownUsers.remove(leave.id);
      _eventsController.add(leave);
    } else if (message.command == 'vote') {
      final vote = VoteMessage.fromJson(message.data as Map<String, dynamic>, users: _knownUsers);
      _eventsController.add(vote);
    } else if (message.command == 'favorite') {
      final vote = FavoriteMessage.fromJson(message.data as Map<String, dynamic>, users: _knownUsers);
      _eventsController.add(vote);
    }
  }

  void dispose() {
    _advanceController.close();
    _chatMessagesController.close();
    _eventsController.close();
    _client.close();
    if (_ws != null) {
      _ws.sink.close();
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
      .map<User>((Map<String, dynamic> u) => User.fromJson(u))
      .forEach((User user) {
        users[user.id] = user;
      });

    final serverTime = DateTime.fromMillisecondsSinceEpoch(json['time'] as int);
    final tempSyncher = _TimeSynchronizer();
    tempSyncher.serverTime = serverTime;

    return UwaveNowState(
      motd: json['motd'] as String,
      users: users,
      currentUser: json['user'] != null
        ? User.fromJson(json['user'] as Map<String, dynamic>)
        : null,
      currentEntry: json['booth'] != null
        ? HistoryEntry.fromJson(json['booth'] as Map<String, dynamic>, users: users, serverTime: tempSyncher)
        : null,
      waitlist: json['waitlist'].cast<String>().toList() as List<String>,
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
      id: json['_id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar'] as String,
      roles: json['roles'].cast<String>().toList() as List<String>,
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
      id: json['_id'] as String,
      sourceType: json['sourceType'] as String,
      sourceID: json['sourceID'] as String,
      artist: json['artist'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnail'] as String,
      duration: json['duration'] as int,
      sourceData: json['sourceData'] as Map<String, dynamic>,
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
      id: json['_id'] as String,
      media: json['media'] is String
        ? (medias != null ? medias[json['media'] as String] : null)
        : Media.fromJson(json['media'] as Map<String, dynamic>),
      artist: json['artist'] as String,
      title: json['title'] as String,
      start: json['start'] as int,
      end: json['end'] as int,
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
      id: json['_id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
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
      id: json['_id'] as String,
      userID: json['user'] as String,
      user: users != null ? users[json['user']] : null,
      media: json['media']['media'] is String
        ? (medias != null ? medias[json['media']['media'] as String] : null)
        : Media.fromJson(json['media']['media'] as Map<String, dynamic>),
      artist: json['media']['artist'] as String,
      title: json['media']['title'] as String,
      start: json['media']['start'] as int,
      end: json['media']['end'] as int,
      timestamp: serverTime.toLocal(json['playedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['playedAt'] as int)
          : DateTime.parse(json['playedAt'] as String)),
    );
  }
}
