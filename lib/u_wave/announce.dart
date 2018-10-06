import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../event_source/event_source.dart' show EventSource;

typedef OnUpdateCallback = void Function(Map<String, UwaveServer> servers);
class UwaveAnnounceClient {
  final String _url;
  final Map<String, UwaveServer> _servers = {};
  EventSource _events;

  OnUpdateCallback onUpdate;
  Iterable<UwaveServer> get servers => _servers.values;

  UwaveAnnounceClient({String url})
      : _url = url ?? 'https://announce.u-wave.net'
  {
    final eventsUri = Uri.parse(_url).replace(path: '/events');
    _events = EventSource(eventsUri);
    _events.events.listen((event) {
      print('update: ${event.name} ${event.data}');
      if (event.name == 'message') {
        _onEvent(event.data);
      }
    });

    fetchServers();
  }

  void _updated() {
    print('emit update');
    if (onUpdate != null) onUpdate(_servers);
  }

  void _onEvent(String data) {
    final server = UwaveServer.fromJson(json.decode(data));
    _servers[server.publicKey] = server;
    _updated();
  }

  Future<List<UwaveServer>> fetchServers() async {
    final response = await http.get(_url);
    final parsed = json.decode(response.body);
    final list = parsed['servers']
        .cast<Map<String, Object>>()
        .map<UwaveServer>((json) => UwaveServer.fromJson(json))
        .toList();

    list.forEach((server) {
      _servers[server.publicKey] = server;
    });

    _updated();

    return list;
  }

  void close() {
    _events.close();
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
