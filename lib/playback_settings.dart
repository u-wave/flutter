import 'package:flutter/material.dart';
import './settings.dart' show Settings, UwaveSettings;

Text _getAudioOnlyValue(bool audioOnly, bool audioOnlyData) {
  return audioOnly ? const Text('Always') :
    audioOnlyData ? const Text('When using mobile data') :
    const Text('Never');
}

class PlaybackSettingsRoute extends StatefulWidget {
  PlaybackSettingsRoute();

  @override
  _PlaybackSettingsRouteState createState() => _PlaybackSettingsRouteState();
}

class _PlaybackSettingsRouteState extends State<PlaybackSettingsRoute> {
  void _audioOnlyDialog() {
    showDialog<Null>(
      context: context,
      builder: (BuildContext context) {
        void apply(bool audioOnly, bool audioOnlyData) {
          final settings = UwaveSettings.of(context);
          settings.audioOnly = audioOnly;
          settings.audioOnlyData = audioOnlyData;

          Navigator.pop(context, null);
        }

        return SimpleDialog(
          title: const Text('Audio-only playback'),
          children: [
            SimpleDialogOption(
              child: _getAudioOnlyValue(true, true),
              onPressed: () { apply(true, true); },
            ),
            SimpleDialogOption(
              child: _getAudioOnlyValue(false, true),
              onPressed: () { apply(false, true); },
            ),
            SimpleDialogOption(
              child: _getAudioOnlyValue(false, false),
              onPressed: () { apply(false, false); },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormFields(Settings settings) {
    return Column(
      children: ListTile.divideTiles(
        context: context,
        tiles: [
          ListTile(
            title: const Text('Audio-only playback'),
            subtitle: _getAudioOnlyValue(settings.audioOnly, settings.audioOnlyData),
            onTap: _audioOnlyDialog,
          ),
          ListTile(
            title: const Text('Preferred video resolution'),
            subtitle: Text(settings.preferredVideoResolution),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Limit resolution using mobile data'),
            subtitle: Text(settings.maxVideoResolutionData),
            onTap: () {},
          ),
        ],
      ).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = UwaveSettings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Settings'),
      ),
      body: _buildFormFields(settings),
    );
  }
}
