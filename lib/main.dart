import 'dart:async';
import 'package:flutter/material.dart';
import './uwave.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'üWave',
      theme: new ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF9D2053),
        accentColor: Color(0xFFB20062),
      ),
      home: new UwaveServerList(title: 'Public üWave Servers'),
    );
  }
}

class UwaveServerList extends StatefulWidget {
  final String title;

  UwaveServerList({Key key, this.title}) : super(key: key);

  @override
  _UwaveServerListState createState() => new _UwaveServerListState();
}

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

class _UwaveServerListState extends State<UwaveServerList> {
  UwaveAnnounceClient _client = UwaveAnnounceClient();
  List<UwaveServer> _servers = List();

  void _updateServers() {
    _client.listServers().then((servers) {
      setState(() {
        _servers = servers;
      });
    });
  }

  void _listen(UwaveServer server) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UwaveListen(server: server)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the UwaveServerList object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              _servers.map<Widget>((server) => _renderServer(server)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateServers,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _renderServer(UwaveServer server) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          ListTile(
            title: Text(server.name),
            subtitle: Text(server.subtitle),
            trailing: const Icon(Icons.more_vert),
            onTap: () {
              _listen(server);
            },
          ),
        ],
      ),
    );
  }
}
