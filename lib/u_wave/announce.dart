import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:w3c_event_source/event_source.dart' show EventSource, MessageEvent;

typedef OnUpdateCallback = void Function(Map<String, UwaveServer> servers);
class UwaveAnnounceClient {
  final String _url;
  final Map<String, UwaveServer> _servers = {};
  StreamSubscription<MessageEvent> _events;

  final StreamController<Map<String, UwaveServer>> _onUpdate = StreamController.broadcast();
  Stream<Map<String, UwaveServer>> get onUpdate => _onUpdate.stream;
  Iterable<UwaveServer> get servers => _servers.values;

  UwaveAnnounceClient({String url})
      : _url = url ?? 'https://announce.u-wave.net'
  {
    final eventsUri = Uri.parse(_url).replace(path: '/events');
    _events = EventSource(eventsUri).events.listen((event) {
      debugPrint('update: ${event.name} ${event.data}');
      if (event.name == 'message') {
        _onEvent(event.data);
      }
    });

    fetchServers();
  }

  void _updated() {
    _onUpdate.add(_servers);
  }

  void _onEvent(String data) {
    final server = UwaveServer.fromJson(json.decode(data) as Map<String, dynamic>);
    _servers[server.publicKey] = server;
    _updated();
  }

  Future<List<UwaveServer>> fetchServers() async {
    final response = await http.get(_url);
    final Map<String, dynamic> parsed = json.decode(response.body);
    final List<UwaveServer> list = parsed['servers']
        .cast<Map<String, dynamic>>()
        .map<UwaveServer>((Map<String, dynamic> json) => UwaveServer.fromJson(json))
        .toList();

    for (final server in list) {
      _servers[server.publicKey] = server;
    }

    _updated();

    return list;
  }

  void close() {
    _events.cancel();
    _onUpdate.close();
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
      publicKey: json['publicKey'] as String,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      url: json['url'] as String,
      apiUrl: json['apiUrl'] as String,
      socketUrl: json['socketUrl'] as String,
      currentMedia: json['booth'] != null
        ? CurrentMedia.fromJson(json['booth'] as Map<String, dynamic>)
        : null,
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
      artist: json['media']['artist'] as String,
      title: json['media']['title'] as String,
      thumbnailUrl: json['media']['thumbnail'] as String,
    );
  }
}
