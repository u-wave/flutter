import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import './uwave.dart';
import './server_list.dart' show ServerThumbnail;

class UwaveListen extends StatefulWidget {
  final UwaveServer server;

  UwaveListen({Key key, this.server}) : super(key: key);

  @override
  _UwaveListenState createState() => new _UwaveListenState();
}

class _UwaveListenState extends State<UwaveListen> {
  static const playerChannel = MethodChannel('u-wave.net/player');
  static bool _playerPluginInitialized = false;
  int _playerTexture;
  UwaveClient _client;
  bool _clientConnected = false;
  HistoryEntry _playing = null;
  StreamSubscription<HistoryEntry> _advanceSubscription;

  @override
  initState() {
    super.initState();
    _client = UwaveClient(
      apiUrl: widget.server.apiUrl,
      socketUrl: widget.server.socketUrl,
    );

    playerChannel.setMethodCallHandler((methodCall) async {
      if (methodCall.method == 'download') {
        return await _download(Map<String, String>.from(methodCall.arguments));
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

    _client.init().then((_) {
      setState(() {
        _clientConnected = true;
      });
    });
  }

  @override
  dispose() {
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
    final seek = entry.timestamp.difference(DateTime.now())
        + Duration(seconds: entry.start);

    debugPrint('Playing entry ${entry.media.artist} - ${entry.media.title} from $seek');
    _playing = entry;
    playerChannel.invokeMethod('play', <String, String>{
      'sourceType': entry.media.sourceType,
      'sourceID': entry.media.sourceID,
      'seek': '${seek.isNegative ? 0 : seek.inMilliseconds}',
      'audioOnly': 'true',
    }).then((result) {
      setState(() {
        _playerTexture = result as int;
        debugPrint('Using _playerTexture $_playerTexture');
      });
    });
  }

  /// Stop playing.
  _stop() {
    debugPrint('Stopping playback');
    playerChannel.invokeMethod('play', null);
    _playerTexture = null;
    _playing = null;
  }

  @override
  Widget build(BuildContext context) {
    Widget player;
    if (_playing != null) {
      player = PlayerView(textureId: _playerTexture, entry: _playing);
    } else if (_clientConnected) {
      // nobody playing right now
      player = Container();
    } else {
      // still loading
      player = ServerThumbnail(server: widget.server);
    }

    return Scaffold(
      appBar: AppBar(
        title: _playing == null
          ? Text(widget.server.name)
          : CurrentMediaTitle(artist: _playing.artist, title: _playing.title),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Flexible(
                  flex: 1,
                  child: player,
                ),
                Expanded(
                  flex: 1,
                  child: ChatMessages(
                    notifications: _client.events,
                    messages: _client.chatMessages,
                  ),
                ),
              ],
            )
          ),
          ChatInput(),
        ],
      ),
    );
  }
}

class PlayerView extends StatelessWidget {
  final int textureId;
  final HistoryEntry entry;

  PlayerView({this.textureId, this.entry});

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
                ? Container() // nothing
                : Texture(textureId: textureId)
            ),
          ),
          MediaProgressBar(
            startTime: entry.timestamp,
            startOffset: entry.start,
            endOffset: entry.end,
          ),
        ],
      ),
    );
  }
}

class MediaProgressBar extends StatefulWidget {
  final DateTime startTime;
  final int startOffset;
  final int endOffset;

  MediaProgressBar({this.startTime, this.startOffset, this.endOffset});

  @override
  _MediaProgressBarState createState() => new _MediaProgressBarState();
}

class _MediaProgressBarState extends State<MediaProgressBar> {
  Timer _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _update();
    });
    _update();
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  void _update() {
    final start = widget.startTime.add(Duration(seconds: widget.startOffset));
    final current = DateTime.now().difference(widget.startTime);
    final offset = current.inSeconds;
    final duration = widget.endOffset - widget.startOffset;

    setState(() {
      _progress = offset / duration;
    });
  }

  @override
  Widget build(_) {
    return LinearProgressIndicator(value: _progress);
  }
}

class ChatMessages extends StatefulWidget {
  final Stream<dynamic> notifications;
  final Stream<ChatMessage> messages;

  ChatMessages({Key key, this.notifications, this.messages}) : super(key: key);

  @override
  _ChatMessagesState createState() => new _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  final List<dynamic> _messages = [];
  StreamSubscription<ChatMessage> _chatSubscription;
  StreamSubscription<dynamic> _notificationsSubscription;

  static _isSupportedNotification(message) {
    return message is UserJoinMessage ||
        message is UserLeaveMessage;
  }

  @override
  void initState() {
    super.initState();

    _chatSubscription = widget.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
    });
    _notificationsSubscription = widget.notifications.listen((message) {
      setState(() {
        if (_isSupportedNotification(message)) {
          _messages.add(message);
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _chatSubscription.cancel();
    _notificationsSubscription.cancel();
    _chatSubscription = null;
    _notificationsSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF151515),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          if (message is ChatMessage) {
            return ChatMessageView(message);
          }
          if (message is UserJoinMessage) {
            return UserJoinMessageView(message);
          }
          if (message is UserLeaveMessage) {
            return UserLeaveMessageView(message);
          }
          return Text('Unexpected message type!');
        },
      ),
    );
  }
}

class ChatInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF1B1B1B),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: TextField(),
        ),
      ),
    );
  }
}

class UserJoinMessageView extends StatelessWidget {
  final UserJoinMessage message;

  UserJoinMessageView(this.message);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );
    final username = message.user?.username ?? '<unknown>';

    return ListTile(
      dense: true,
      leading: avatar,
      title: Text('$username joined'),
    );
  }
}

class UserLeaveMessageView extends StatelessWidget {
  final UserLeaveMessage message;

  UserLeaveMessageView(this.message);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );
    final username = message.user?.username ?? '<unknown>';

    return ListTile(
      dense: true,
      leading: avatar,
      title: Text('$username left'),
    );
  }
}

class ChatMessageView extends StatelessWidget {
  final ChatMessage message;

  ChatMessageView(this.message);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );

    return ListTile(
      dense: true,
      leading: avatar,
      title: Text(message.user?.username ?? '<unknown>'),
      subtitle: Text(message.message),
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
