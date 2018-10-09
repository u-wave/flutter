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
    final settings = UwaveSettings.of(context);
    _PlaybackTypesDialog.show(
      title: const Text('Playback on WiFi'),
      value: settings.playbackType,
      context: context,
    ).then((type) {
      if (type != null) {
        settings.playbackType = type;
      }
    });
  }

  void _playbackTypeDataDialog() {
    final settings = UwaveSettings.of(context);
    _PlaybackTypesDialog.show(
      title: const Text('Playback on mobile data'),
      value: settings.playbackTypeData,
      context: context,
    ).then((type) {
      if (type != null) {
        settings.playbackTypeData = type;
      }
    });
  }

  Widget _buildFormFields(Settings settings) {
    return Column(
      children: ListTile.divideTiles(
        context: context,
        tiles: [
          SwitchListTile(
            title: const Text('Show current track in notification'),
            value: settings.nowPlayingNotification,
            onChanged: (value) {
              settings.nowPlayingNotification = value;
            },
          ),
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
  final _PlaybackTypeCallback onSelect;
  final Widget title;
  final PlaybackType value;

  _PlaybackTypesDialog({this.onSelect, this.title, this.value});

  @override
  Widget build(_) {
    return SimpleDialog(
      title: title,
      children: [
        RadioListTile(
          title: _getPlaybackValue(PlaybackType.both),
          value: PlaybackType.both,
          groupValue: value,
          onChanged: onSelect,
        ),
        RadioListTile(
          title: _getPlaybackValue(PlaybackType.audioOnly),
          value: PlaybackType.audioOnly,
          groupValue: value,
          onChanged: onSelect,
        ),
        RadioListTile(
          title: _getPlaybackValue(PlaybackType.disabled),
          value: PlaybackType.disabled,
          groupValue: value,
          onChanged: onSelect,
        ),
      ],
    );
  }

  static Future<PlaybackType> show({BuildContext context, Widget title, PlaybackType value}) {
    return showDialog<PlaybackType>(
      context: context,
      builder: (context) => _PlaybackTypesDialog(
        title: title,
        value: value,
        onSelect: (PlaybackType type) {
          Navigator.pop(context, type);
        },
      ),
    );
  }
}
