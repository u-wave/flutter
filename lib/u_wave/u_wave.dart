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

  Stream<ChatMessage> get chatMessages => _chatMessagesController.stream;
  Stream<HistoryEntry> get advanceMessages => _advanceController.stream;
  Stream<dynamic> get events => _eventsController.stream;

  final Map<String, User> _knownUsers = Map();

  UwaveClient({this.apiUrl, socketUrl})
      : _channel = IOWebSocketChannel.connect(socketUrl),
        socketUrl = socketUrl;

  Future<UwaveNowState> init() async {
    _channel.stream.listen((message) {
      if (message == "-") return;
      final decoded = json.decode(message);
      this._onMessage(_SocketMessage.fromJson(decoded));
    });

    final response = await _client.get("$apiUrl/now");
    final nowJson = json.decode(response.body);
    final state = UwaveNowState.fromJson(nowJson);

    if (state.currentEntry != null) {
      _advanceController.add(state.currentEntry);
    }

    state.users.forEach((id, user) {
      _knownUsers[user.id] = user;
    });

    _serverTime.serverTime = state.serverTime;

    return state;
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
  final HistoryEntry currentEntry;
  final List<String> waitlist;
  final DateTime serverTime;

  UwaveNowState({
    this.motd,
    this.users,
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