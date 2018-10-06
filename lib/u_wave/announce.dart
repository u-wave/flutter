import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  void close() {
    // Nothing right now
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
