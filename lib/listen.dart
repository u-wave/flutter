import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' show FlutterSecureStorage;
import './u_wave/announce.dart' show UwaveServer;
import './u_wave/u_wave.dart';
import './server_list.dart' show ServerThumbnail;
import './settings.dart' show UwaveSettings;
import './playback_settings.dart' show PlaybackSettingsRoute;
import './signin_views.dart' show SignInRoute;
import './chat_views.dart' show ChatMessages, ChatInput;
import './notification.dart' show NowPlayingNotification;

class UwaveListen extends StatefulWidget {
  final UwaveServer server;

  UwaveListen({Key key, this.server}) : super(key: key);

  @override
  _UwaveListenState createState() => _UwaveListenState();
}

class _UwaveListenState extends State<UwaveListen> {
  static const playerChannel = MethodChannel('u-wave.net/player');
  static const notificationChannel = MethodChannel('u-wave.net/notification');
  final _playerViewKey = GlobalKey<_UwaveListenState>();
  final _storage = FlutterSecureStorage();
  int _playerTexture;
  UwaveClient _client;
  bool _clientConnected = false;
  bool _signedIn = false;
  bool _showOverlay = false;
  double _aspectRatio;
  HistoryEntry _playing;
  Stream<Duration> _currentProgress;
  StreamSubscription<HistoryEntry> _advanceSubscription;

  @override
  void initState() {
    super.initState();
    _client = UwaveClient(
      apiUrl: widget.server.apiUrl,
      socketUrl: widget.server.socketUrl,
    );

    playerChannel.setMethodCallHandler((methodCall) async {
      if (methodCall.method == 'download') {
        return await _download(Map<String, String>.from(methodCall.arguments));
      }
      if (methodCall.method == 'setAspectRatio') {
        _aspectRatio = methodCall.arguments.toDouble();
        debugPrint('setAspectRatio($_aspectRatio)');
        return null;
      }
      throw MissingPluginException('Unknown method ${methodCall.method}');
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

    final key = widget.server.publicKey;
    _storage.read(key: 'credentials:$key').then((json) {
      final credentials = json is String
        ? UwaveCredentials.deserialize(json)
        : null;
      return _client.init(credentials: credentials);
    }).then((_) {
      setState(() {
        _clientConnected = true;
        _signedIn = _client.currentUser != null;
      });
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
    _stop();
  }

  /// Download a URL's contents to a string.
  ///
  /// This is called by the NewPipe extractor, so I don't have to learn and
  /// ship a Java HTTP client but can instead use the Dart one :P
  Future<String> _download(Map<String, String> headers) async {
    final url = headers.remove('_url');
    final response = await http.get(url, headers: headers);
    if (response.statusCode != 200) {
      throw 'Unexpected response ${response.statusCode} from $url';
    }
    headers['_url'] = url; // restore
    return response.body;
  }

  /// Start playing a history entry.
  _play(HistoryEntry entry) {
    final seek = DateTime.now().difference(entry.timestamp);
    final seekInMedia = seek + Duration(seconds: entry.start);
    final settings = UwaveSettings.of(context);

    debugPrint('Playing entry ${entry.media.artist} - ${entry.media.title} from $seekInMedia');
    _playing = entry;

    _currentProgress = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now().difference(entry.timestamp),
    ).take(seek.inSeconds - entry.start)
        .asBroadcastStream();

    NowPlayingNotification.getInstance().show(
      artist: entry.artist,
      title: entry.title,
      duration: entry.end - entry.start,
      progress: _currentProgress,
    );

    playerChannel.invokeMethod('play', <String, String>{
      'sourceType': entry.media.sourceType,
      'sourceID': entry.media.sourceID,
      'seek': '${seekInMedia.isNegative ? 0 : seekInMedia.inMilliseconds}',
      'playbackType': '${settings.playbackType.index}',
    }).then((result) {
      setState(() {
        if (result == null) {
          _playerTexture = null;
          debugPrint('Audio-only: no player texture');
        } else {
          _playerTexture = result as int;
          debugPrint('Using player texture #$_playerTexture');
        }
      });
    });
  }

  /// Stop playing.
  _stop() {
    debugPrint('Stopping playback');
    playerChannel.invokeMethod('play', null);
    NowPlayingNotification.getInstance()
      .close();
    _playerTexture = null;
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
      setState(() {
        _signedIn = _client.currentUser != null;
      });
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
    if (_signedIn) {
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
          textureId: _playerTexture,
          aspectRatio: _aspectRatio,
          entry: _playing,
          currentProgress: _currentProgress,
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

    final Widget footer = _signedIn
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

  PlayerView({this.textureId, this.entry, this.currentProgress,this.aspectRatio = 16 / 9});

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
          case ConnectionState.active:
            progress = snapshot.data;
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
