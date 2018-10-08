import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

enum PlaybackType {
  disabled,
  audioOnly,
  both,
}

class SettingUpdate {
  final String name;
  final dynamic value;

  SettingUpdate(this.name, this.value);
}

class Settings {
  static const _DEFAULT_PREFERRED_VIDEO_RESOLUTION = '360p';
  static const _DEFAULT_MAX_VIDEO_RESOLUTION_DATA = '360p';
  static const _DEFAULT_PREFERRED_AUDIO = 'best';
  static const _DEFAULT_MAX_AUDIO_DATA = 'best';
  static const _DEFAULT_PLAYBACK_TYPE = PlaybackType.both;
  static const _DEFAULT_PLAYBACK_TYPE_DATA = PlaybackType.both;

  final SharedPreferences _prefs;
  final StreamController<SettingUpdate> _updateController = StreamController.broadcast();

  Stream<SettingUpdate> get onUpdate => _updateController.stream;

  Settings._(this._prefs);

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings._(prefs);
  }

  void _emitUpdate(String name, dynamic value) {
    _updateController.add(SettingUpdate(name, value));
  }

  String get preferredVideoResolution => _prefs.getString('videoResolution') ?? _DEFAULT_PREFERRED_VIDEO_RESOLUTION;

  String get maxVideoResolutionData => _prefs.getString('videoResolutionData') ?? _DEFAULT_MAX_VIDEO_RESOLUTION_DATA;

  String get preferredAudioBitrate => _prefs.getString('audioBitrate') ?? _DEFAULT_PREFERRED_AUDIO;

  String get maxAudioBitrateData => _prefs.getString('audioBitrateData') ?? _DEFAULT_MAX_AUDIO_DATA;

  PlaybackType get playbackType {
    int index = _prefs.getInt('playbackType');
    if (index == null) return _DEFAULT_PLAYBACK_TYPE;
    return PlaybackType.values[index];
  }
  set playbackType (PlaybackType value) {
    final old = playbackType;
    _prefs.setInt('playbackType', value.index);
    if (old != value) _emitUpdate('playbackType', value);
  }

  PlaybackType get playbackTypeData {
    int index = _prefs.getInt('playbackTypeData');
    if (index == null) return _DEFAULT_PLAYBACK_TYPE_DATA;
    return PlaybackType.values[index];
  }
  set playbackTypeData (PlaybackType value) {
    final old = playbackTypeData;
    _prefs.setInt('playbackTypeData', value.index);
    if (old != value) _emitUpdate('playbackTypeData', value);
  }
}

class UwaveSettings extends StatefulWidget {
  final Settings settings;
  final Widget child;

  UwaveSettings({this.settings, this.child});

  @override
  _UwaveSettingsState createState() => _UwaveSettingsState();

  static Settings of(BuildContext context) {
    return _UwaveSettingsProvider.of(context)?.settings;
  }
}

class _UwaveSettingsState extends State<UwaveSettings> {
  StreamSubscription<SettingUpdate> _sub;
  int _id = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.settings.onUpdate.listen((_) {
      setState(() {
        _id++;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _sub.cancel();
    _sub = null;
  }

  @override
  Widget build(_) {
    return _UwaveSettingsProvider(
      id: _id,
      settings: widget.settings,
      child: widget.child,
    );
  }
}

class _UwaveSettingsProvider extends InheritedWidget {
  final Settings settings;
  final int id;

  _UwaveSettingsProvider({Key key, Widget child, this.id, this.settings}) : super(key: key, child: child);

  static _UwaveSettingsProvider of(BuildContext context) {
    return context.inheritFromWidgetOfExactType(_UwaveSettingsProvider);
  }

  @override
  bool updateShouldNotify(_UwaveSettingsProvider old) => id != old.id;
}
