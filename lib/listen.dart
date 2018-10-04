import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import './uwave.dart';

class UwaveListen extends StatefulWidget {
  final UwaveServer server;

  UwaveListen({Key key, this.server}) : super(key: key);

  @override
  _UwaveListenState createState() => new _UwaveListenState();
}

class _UwaveListenState extends State<UwaveListen> {
  static const playerChannel = MethodChannel('u-wave.net/player');
  static int _playerTexture;
  UwaveClient _client;
  HistoryEntry _playing;

  @override
  initState() {
    super.initState();
    _client = UwaveClient(
      apiUrl: widget.server.apiUrl,
      socketUrl: widget.server.socketUrl,
    );

    playerChannel.setMethodCallHandler((methodCall) async {
      if (methodCall.method == 'download') {
        final headers = Map<String, String>.from(methodCall.arguments);
        final url = headers.remove('_url');
        final response = await http.get(url, headers: headers);
        if (response.statusCode != 200) {
          throw 'Unexpected response ${response.statusCode} from ${url}';
        }
        return response.body;
      }
      throw MissingPluginException('Unknown method ${methodCall.method}');
    });

    final init = _playerTexture == null
      ?  playerChannel.invokeMethod('init').then((result) {
        _playerTexture = result as int;
        return _client.init();
      })
      : _client.init();

    init.then((now) {
      setState(() {
        if (now.currentEntry != null) {
          _play(now.currentEntry);
        }
      });
    });
  }

  _play(HistoryEntry entry) {
    playerChannel.invokeMethod('play', <String, String>{
      'sourceType': entry.media.sourceType,
      'sourceID': entry.media.sourceID,
    });
    _playing = entry;
  }

  @override
  Widget build(BuildContext context) {
    final loadingVideo = widget.server.currentMedia != null
      ? Image.network(widget.server.currentMedia.thumbnailUrl)
      : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: Column(
            children: <Widget>[
              Flexible(
                flex: 1,
                child: Container(color: Color(0xFF000000), child: AspectRatio(
                  aspectRatio: 16 / 9,
                  // TODO draw NewPipe onto a Texture instance here
                  // https://docs.flutter.io/flutter/widgets/Texture-class.html
                  child: Center(
                    child: _playerTexture == null
                      ? loadingVideo
                      : Texture(textureId: _playerTexture)
                  ),
                )),
              ),
              Expanded(
                flex: 1,
                child: ChatMessages(messages: _client.chatMessages),
              ),
            ],
          )),
          ChatInput(),
        ],
      ),
    );
  }
}

class ChatMessages extends StatefulWidget {
  final Stream<ChatMessage> messages;

  ChatMessages({Key key, this.messages}) : super(key: key);

  @override
  _ChatMessagesState createState() => new _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  final List<ChatMessage> _messages = [];

  @override
  initState() {
    super.initState();
    widget.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF151515),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _messages.length,
        itemBuilder: (context, index) => ChatMessageView(_messages[index]),
      ),
    );
  }
}

class ChatInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: TextField(),
      ),
    );
  }
}

class ChatMessageView extends StatelessWidget {
  final ChatMessage message;

  ChatMessageView(this.message);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundImage: NetworkImage("https://sigil.u-wave.net/ejemplo"),
      ),
      title: Text(message.userID),
      subtitle: Text(message.message),
    );
  }
}
