import 'dart:async';
import 'package:flutter/material.dart';
import './uwave.dart';

class UwaveListen extends StatefulWidget {
  final UwaveServer server;

  UwaveListen({Key key, this.server}) : super(key: key);

  @override
  _UwaveListenState createState() => new _UwaveListenState();
}

class _UwaveListenState extends State<UwaveListen> {
  UwaveClient _client;

  @override
  initState() {
    super.initState();
    _client = UwaveClient(
      apiUrl: widget.server.apiUrl,
      socketUrl: widget.server.socketUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server.name),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
              child: Column(
            children: <Widget>[
              Flexible(
                  flex: 1,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    // TODO draw NewPipe onto a Texture instance here
                    // https://docs.flutter.io/flutter/widgets/Texture-class.html
                    child: Center(child: Container(color: Color(0xFF000000))),
                  )),
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
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _messages.length,
      itemBuilder: (context, index) => ChatMessageView(_messages[index]),
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
