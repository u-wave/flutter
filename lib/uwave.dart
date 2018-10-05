import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

class UwaveAnnounceClient {
  final String _url;

  UwaveAnnounceClient({String url})
      : _url = url ?? 'https://announce.u-wave.net';

  Future<List<UwaveServer>> listServers() async {
    final response = await http.get(_url);
    final parsed = json.decode(response.body);
    return parsed['servers']
        .cast<Map<String, Object>>()
        .map<UwaveServer>((json) => UwaveServer.fromJson(json))
        .toList();
  }
}

class SocketMessage {
  final String command;
  final dynamic data;

  SocketMessage({this.command, this.data});

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    return SocketMessage(
      command: json['command'],
      data: json['data'],
    );
  }
}

class ChatMessage {
  final String id;
  final User user;
  final String message;
  final DateTime timestamp;

  ChatMessage({this.id, this.user, this.message, this.timestamp});

  factory ChatMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users}) {
    return ChatMessage(
      id: json['id'],
      user: users != null ? users[json['userID']] : null,
      message: json['message'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

class AdvanceMessage {
  final HistoryEntry entry;

  AdvanceMessage({this.entry});

  factory AdvanceMessage.fromJson(Map<String, dynamic> json, {Map<String, User> users}) {
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
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['playedAt']),
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
      this._onMessage(SocketMessage.fromJson(decoded));
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

    return state;
  }

  void _onMessage(message) {
    if (message.command == 'chatMessage') {
      final chat = ChatMessage.fromJson(message.data, users: _knownUsers);
      this._chatMessagesController.add(chat);
    }
    if (message.command == 'advance') {
      final advance = AdvanceMessage.fromJson(message.data, users: _knownUsers);
      this._advanceController.add(advance.entry);
    }
    if (message.command == 'join') {
      final join = UserJoinMessage.fromJson(message.data);
      this._knownUsers[join.user.id] = join.user;
      this._eventsController.add(join);
    }
    if (message.command == 'leave') {
      final leave = UserLeaveMessage.fromJson(message.data, users: _knownUsers);
      this._knownUsers.remove(leave.id);
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

  UwaveNowState({
    this.motd,
    this.users,
    this.currentEntry,
    this.waitlist,
  });

  factory UwaveNowState.fromJson(Map<String, dynamic> json) {
    final Map<String, User> users = {};

    json['users']
      .map<User>((u) => User.fromJson(u))
      .forEach((user) {
        users[user.id] = user;
      });

    return UwaveNowState(
      motd: json['motd'],
      users: users,
      currentEntry: json['booth'] != null
        ? HistoryEntry.fromJson(json['booth'], users: users)
        : null,
      waitlist: json['waitlist'].cast<String>().toList(),
    );
  }
}

class CurrentMedia {
  final String artist;
  final String title;
  final String thumbnailUrl;

  CurrentMedia({
    this.artist,
    this.title,
    this.thumbnailUrl,
  });

  factory CurrentMedia.fromJson(Map<String, dynamic> json) {
    return CurrentMedia(
      artist: json['media']['artist'],
      title: json['media']['title'],
      thumbnailUrl: json['media']['thumbnail'],
    );
  }
}

class UwaveServer {
  final String publicKey;
  final String name;
  final String subtitle;
  final String description;
  final String url;
  final String apiUrl;
  final String socketUrl;
  final CurrentMedia currentMedia;

  UwaveServer({
    this.publicKey,
    this.name,
    this.subtitle,
    this.description,
    this.url,
    this.apiUrl,
    this.socketUrl,
    this.currentMedia,
  });

  factory UwaveServer.fromJson(Map<String, dynamic> json) {
    return UwaveServer(
      publicKey: json['publicKey'],
      name: json['name'],
      subtitle: json['subtitle'],
      description: json['description'],
      url: json['url'],
      apiUrl: json['apiUrl'],
      socketUrl: json['socketUrl'],
      currentMedia: json['booth'] != null ? CurrentMedia.fromJson(json['booth']) : null,
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

  factory HistoryEntry.fromJson(Map<String, dynamic> json, {Map<String, Media> medias, Map<String, User> users}) {
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
    );
  }
}
