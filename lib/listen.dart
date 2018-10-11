import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import 'package:connectivity/connectivity.dart' show Connectivity, ConnectivityResult;
import './u_wave/announce.dart' show UwaveServer;
import './u_wave/u_wave.dart';
import './server_list.dart' show ServerThumbnail;
import './settings.dart' show UwaveSettings, PlaybackType;
import './playback_settings.dart' show PlaybackSettingsRoute;
import './signin_views.dart' show SignInRoute;
import './chat_views.dart' show ChatMessages, ChatInput;
import './notification.dart' show NowPlayingNotification;
import './player.dart' show Player, PlaybackSettings;

class UwaveListen extends StatefulWidget {
  final UwaveServer server;

  UwaveListen({Key key, this.server}) : super(key: key);

  @override
  _UwaveListenState createState() => _UwaveListenState();
}

class _UwaveListenState extends State<UwaveListen> {
  final _playerViewKey = GlobalKey<_UwaveListenState>();
  final _storage = FlutterSecureStorage();
  UwaveClient _client;
  bool _clientConnected = false;
  bool _showOverlay = false;
  HistoryEntry _playing;
  PlaybackType _playbackType = PlaybackType.disabled;
  PlaybackSettings _playbackSettings;
  StreamSubscription<HistoryEntry> _advanceSubscription;
  StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _client = UwaveClient(
      apiUrl: widget.server.apiUrl,
      socketUrl: widget.server.socketUrl,
    );

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final settings = UwaveSettings.of(context);
      if (settings.playbackType == settings.playbackTypeData) {
        return; // no need to switch playback types
      }

      final playbackType = result == ConnectivityResult.wifi
          ? settings.playbackType
          : settings.playbackTypeData;

      debugPrint('Connectivity changed, switching to $playbackType');
      Player.getInstance()
          .setPlaybackType(playbackType);

      setState(() { _playbackType = playbackType; });
    });

    _advanceSubscription = _client.advanceMessages.listen((entry) {
      setState(() {
        if (entry != null) {
          _play(entry);
        } else {
          _stop();
        }
      });
    });

    _connect();
  }

  Future<Null> _connect() async {
    final key = widget.server.publicKey;
    final json = await _storage.read(key: 'credentials:$key');
    final credentials = json is String
      ? UwaveCredentials.deserialize(json)
      : null;

    await _client.init(credentials: credentials);

    setState(() {
      _clientConnected = true;
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_playing != null) _play(_playing);
  }

  @override
  void dispose() {
    super.dispose();
    _advanceSubscription.cancel();
    _connectivitySubscription.cancel();
    _stop();
  }

  /// Start playing a history entry.
  Future<Null> _play(HistoryEntry entry) async {
    final player = Player.getInstance();
    final playbackSettings = await player.play(entry, _playbackType);

    if (playbackSettings.hasTexture) {
      debugPrint('Using player texture #${playbackSettings.texture}');
    } else {
      debugPrint('Audio-only: no player texture');
    }

    setState(() {
      _playing = entry;
      _playbackSettings = playbackSettings;
    });

    NowPlayingNotification.getInstance().show(
      artist: entry.artist,
      title: entry.title,
      duration: entry.end - entry.start,
      progress: playbackSettings.onProgress,
    );
  }

  /// Stop playing.
  _stop() {
    debugPrint('Stopping playback');
    Player.getInstance()
      ..stop();
    NowPlayingNotification.getInstance()
      ..close();
    _playing = null;
  }

  Future<Null> _showSignInPage() async {
    await Navigator.push(context, MaterialPageRoute(
      maintainState: true,
      builder: (context) => SignInRoute(
        uwave: _client,
        onComplete: (creds) {
          if (creds != null) {
            final key = widget.server.publicKey;
            _storage.write(
              key: 'credentials:$key',
              value: creds.serialize(),
            );
          }
          Navigator.pop(context);
        },
      ),
    ));
  }

  void _signIn() {
    _showSignInPage().then((_) {
      setState(() { /* rerender based on _client.currentUser */ });
    });
  }

  void _sendChat(String message) {
    _client.sendChatMessage(message);
  }

  void _onTapDown(BuildContext context, TapDownDetails details) {
    final RenderBox playerBox = _playerViewKey.currentContext.findRenderObject();
    final tapPosition = playerBox.globalToLocal(details.globalPosition);
    final shouldShow = playerBox.paintBounds.contains(tapPosition);

    if (_showOverlay != shouldShow) {
      setState(() {
        _showOverlay = shouldShow;
      });
    }
  }

  void _onOpenPlaybackSettings() {
    Navigator.push(context, MaterialPageRoute(
      maintainState: true,
      builder: (_) => PlaybackSettingsRoute(),
    ));
  }

  Widget _buildVoteButtons() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.thumb_up),
            onPressed: () {
              _client.upvote();
            },
          ),
          // TODO implement
          // IconButton(
          //   icon: const Icon(Icons.favorite_border, color: Color(0xFF9D2053)),
          // ),
          IconButton(
            icon: const Icon(Icons.thumb_down),
            onPressed: () {
              _client.downvote();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsIcon() {
    return Positioned(
      top: 8.0,
      right: 8.0,
      child: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: _onOpenPlaybackSettings,
      ),
    );
  }

  Widget _buildPlayerOverlay() {
    final List<Widget> children = [];
    if (_client.currentUser != null) {
      children.add(_buildVoteButtons());
    }
    children.add(_buildSettingsIcon());

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Color(0x77000000),
        child: Stack(children: children),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_playing != null) {
      final children = <Widget>[
        PlayerView(
          textureId: _playbackSettings.texture,
          aspectRatio: _playbackSettings.aspectRatio,
          entry: _playing,
          currentProgress: _playbackSettings.onProgress,
        ),
      ];

      if (_showOverlay) {
        children.add(_buildPlayerOverlay());
      }

      return Stack(
        key: _playerViewKey,
        children: children,
      );
    }
    if (_clientConnected) {
      // nobody playing right now
      return Container();
    }
    // still loading
    // TODO add loading spinner overlay using a Stack widget
    return ServerThumbnail(server: widget.server);
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = ChatMessages(
      notifications: _client.events,
      messages: _client.chatMessages,
    );

    final Widget footer = _client.currentUser != null
      ? ChatInput(user: _client.currentUser, onSend: _sendChat)
      : SignInButton(serverName: widget.server.name, onSignIn: _signIn);

    return Scaffold(
      appBar: AppBar(
        title: _playing == null
          ? Text(widget.server.name)
          : CurrentMediaTitle(artist: _playing.artist, title: _playing.title),
      ),
      body: GestureDetector(
        onTapDown: (details) => _onTapDown(context, details),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Flexible(flex: 0, child: _buildPlayer()),
                  Expanded(flex: 1, child: chatMessages),
                ],
              )
            ),
            footer,
          ],
        ),
      ),
    );
  }
}

class PlayerView extends StatelessWidget {
  final int textureId;
  final HistoryEntry entry;
  final Stream<Duration> currentProgress;
  final double aspectRatio;

  PlayerView({this.textureId, this.entry, this.currentProgress, this.aspectRatio = 16 / 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF000000),
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: textureId == null
                ? Image.network(entry.media.thumbnailUrl)
                : AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Texture(textureId: textureId,
                  )),
            ),
          ),
          MediaProgressBar(
            currentProgress: currentProgress,
            duration: Duration(seconds: entry.end - entry.start),
          ),
        ],
      ),
    );
  }
}

class MediaProgressBar extends StatelessWidget {
  final Stream<Duration> currentProgress;
  final Duration duration;

  MediaProgressBar({this.currentProgress, this.duration});

  @override
  Widget build(_) {
    return StreamBuilder<Duration>(
      stream: currentProgress,
      builder: (_, snapshot) {
        Duration progress = const Duration(seconds: 0);
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            progress = const Duration(seconds: 0);
            break;
          case ConnectionState.active:
            progress = snapshot.data;
            break;
          case ConnectionState.done:
            progress = duration;
            break;
        }
        return LinearProgressIndicator(
          value: progress.inSeconds / duration.inSeconds,
        );
      },
    );
  }
}

class SignInButton extends StatelessWidget {
  final String serverName;
  final VoidCallback onSignIn;

  SignInButton({this.serverName, this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FlatButton(
              color: Theme.of(context).primaryColor,
              textTheme: ButtonTextTheme.primary,
              child: Text('Sign In to $serverName'),
              onPressed: onSignIn,
            ),
          ),
        ),
      ],
    );
  }
}

class CurrentMediaTitle extends StatelessWidget {
  final String artist;
  final String title;

  CurrentMediaTitle({ this.artist, this.title });

  @override
  Widget build(BuildContext context) {
    return RichText(
      softWrap: false,
      overflow: TextOverflow.fade,
      text: TextSpan(
        style: Theme.of(context).primaryTextTheme.title,
        children: <TextSpan>[
          TextSpan(text: artist),
          const TextSpan(text: ' – '),
          TextSpan(
            text: title,
            style: TextStyle(color: Colors.white.withOpacity(0.7),
          )),
        ],
      ),
    );
  }
}
