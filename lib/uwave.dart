import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  final String userID;
  final String message;
  final DateTime timestamp;

  ChatMessage({this.id, this.userID, this.message, this.timestamp});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      userID: json['userID'],
      message: json['message'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

class UwaveClient {
  final String apiUrl;
  final String socketUrl;
  final http.Client _client = http.Client();
  final WebSocketChannel _channel;
  final StreamController<ChatMessage> _chatMessagesController =
      StreamController.broadcast();
  Stream<ChatMessage> get chatMessages => _chatMessagesController.stream;

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
    return UwaveNowState.fromJson(nowJson);
  }

  void _onMessage(message) {
    if (message.command == "chatMessage") {
      this._chatMessagesController.add(ChatMessage.fromJson(message.data));
    }
  }

  void dispose() {
    _client.close();
    if (_channel != null) {
      _channel.sink.close(ws_status.goingAway);
    }
  }
}

class UwaveNowState {
  final String motd;
  final List<User> users;
  final HistoryEntry currentEntry;
  final List<String> waitlist;

  UwaveNowState({
    this.motd,
    this.users,
    this.currentEntry,
    this.waitlist,
  });

  factory UwaveNowState.fromJson(Map<String, dynamic> json) {

    return UwaveNowState(
      motd: json['motd'],
      users: json['users'].map<User>((u) => User.fromJson(u)).toList(),
      currentEntry: json['booth'] != null
        ? HistoryEntry.fromJson(json['booth'])
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

  factory PlaylistItem.fromJson(Map<String, dynamic> json, [Map<String, Media> medias = Map()]) {
    return PlaylistItem(
      id: json['_id'],
      media: json['media'] is String
        ? medias[json['media']]
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
  final Media media;
  final String artist;
  final String title;
  final int start;
  final int end;
  final DateTime timestamp;

  HistoryEntry(
      {this.id, this.userID, this.media, this.artist, this.title, this.start, this.end, this.timestamp});

  factory HistoryEntry.fromJson(Map<String, dynamic> json, [Map<String, Media> medias = Map()]) {
    return HistoryEntry(
      id: json['_id'],
      userID: json['user'],
      media: json['media']['media'] is String
        ? medias[json['media']['media']]
        : Media.fromJson(json['media']['media']),
      artist: json['media']['artist'],
      title: json['media']['title'],
      start: json['media']['start'],
      end: json['media']['end'],
    );
  }
}
