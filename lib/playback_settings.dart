import 'package:flutter/material.dart';

class PlaybackSettingsRoute extends StatefulWidget {
  PlaybackSettingsRoute();

  @override
  _PlaybackSettingsRouteState createState() => _PlaybackSettingsRouteState();
}

class _PlaybackSettingsRouteState extends State<PlaybackSettingsRoute> {
  Widget _buildFormFields() {
    return Column(
      children: ListTile.divideTiles(
        context: context,
        tiles: [
          ListTile(
            title: const Text('Audio-only playback'),
            subtitle: const Text('When using mobile data'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Preferred video resolution'),
            subtitle: const Text('720p'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Limit resolution using mobile data'),
            subtitle: const Text('240p'),
            onTap: () {},
          ),
        ],
      ).toList(),
    );
  }

  @override
  Widget build(_) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Settings'),
      ),
      body: _buildFormFields(),
    );
  }
}
