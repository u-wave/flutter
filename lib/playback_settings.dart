import 'dart:async' show Future;
import 'package:flutter/material.dart';
import './settings.dart' show Settings, UwaveSettings, PlaybackType;

Text _getPlaybackValue(PlaybackType type) {
  switch (type) {
    case PlaybackType.both: return const Text('Audio and Video');
    case PlaybackType.audioOnly: return const Text('Audio only');
    case PlaybackType.disabled: return const Text('Disabled');
  }
}

class PlaybackSettingsRoute extends StatefulWidget {
  PlaybackSettingsRoute();

  @override
  _PlaybackSettingsRouteState createState() => _PlaybackSettingsRouteState();
}

class _PlaybackSettingsRouteState extends State<PlaybackSettingsRoute> {
  void _playbackTypeDialog() {
    _PlaybackTypesDialog.show(
      title: const Text('Playback on WiFi'),
      context: context,
    ).then((type) {
      if (type != null) {
        final settings = UwaveSettings.of(context);
        settings.playbackType = type;
      }
    });
  }

  void _playbackTypeDataDialog() {
    _PlaybackTypesDialog.show(
      title: const Text('Playback on mobile data'),
      context: context,
    ).then((type) {
      if (type != null) {
        final settings = UwaveSettings.of(context);
        settings.playbackTypeData = type;
      }
    });
  }

  Widget _buildFormFields(Settings settings) {
    return Column(
      children: ListTile.divideTiles(
        context: context,
        tiles: [
          ListTile(
            title: const Text('Playback on WiFi'),
            subtitle: _getPlaybackValue(settings.playbackType),
            onTap: _playbackTypeDialog,
          ),
          ListTile(
            title: const Text('Playback on mobile data'),
            subtitle: _getPlaybackValue(settings.playbackTypeData),
            onTap: _playbackTypeDataDialog,
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

typedef _PlaybackTypeCallback = void Function(PlaybackType);
class _PlaybackTypesDialog extends StatelessWidget {
  final Widget title;
  final _PlaybackTypeCallback onSelect;

  _PlaybackTypesDialog({this.onSelect, this.title});

  @override
  Widget build(_) {
    return SimpleDialog(
      title: title,
      children: [
        SimpleDialogOption(
          child: _getPlaybackValue(PlaybackType.both),
          onPressed: () { onSelect(PlaybackType.both); },
        ),
        SimpleDialogOption(
          child: _getPlaybackValue(PlaybackType.audioOnly),
          onPressed: () { onSelect(PlaybackType.audioOnly); },
        ),
        SimpleDialogOption(
          child: _getPlaybackValue(PlaybackType.disabled),
          onPressed: () { onSelect(PlaybackType.disabled); },
        ),
      ],
    );
  }

  static Future<PlaybackType> show({BuildContext context, Widget title}) {
    return showDialog<PlaybackType>(
      context: context,
      builder: (context) => _PlaybackTypesDialog(
        title: title,
        onSelect: (PlaybackType type) {
          Navigator.pop(context, type);
        },
      ),
    );
  }
}
