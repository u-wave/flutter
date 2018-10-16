import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' show Markdown;
import './u_wave/announce.dart';
import './listen_store.dart' show ListenStore;

typedef OnJoinCallback = void Function(BuildContext, UwaveServer);

class UwaveServerList extends StatefulWidget {
  final String title;
  final OnJoinCallback onJoin;
  final ListenStore listenStore;

  UwaveServerList({Key key, this.title, this.onJoin, this.listenStore}) : super(key: key);

  @override
  _UwaveServerListState createState() => _UwaveServerListState();
}

class _UwaveServerListState extends State<UwaveServerList> {
  UwaveAnnounceClient _client;
  List<UwaveServer> _servers = List();

  void _listen(UwaveServer server) {
    widget.onJoin(context, server);
  }

  void _disconnect() {
    widget.listenStore.disconnect();
    setState(() {
      // Rerender
    });
  }

  @override
  void initState() {
    super.initState();
    _client = UwaveAnnounceClient();
    _client.onUpdate.listen((_) {
      setState(() {
        _servers = _client.servers.toList();
      });
    });
  }

  void reassemble() {
    super.reassemble();
    _client.fetchServers();
  }

  @override
  void dispose() {
    super.dispose();
    _client.close();
    _client = null;
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      const Text('This is alpha quality software—it may crash regularly!'),
    ];

    if (widget.listenStore.server != null) {
      cards.add(CurrentServer(
        server: widget.listenStore.server,
        onOpen: () { _listen(widget.listenStore.server); },
        onDisconnect: _disconnect,
      ));
    }

    cards.addAll(
      _servers.map<Widget>((server) => ServerCard(
        server: server,
        onJoin: () { _listen(server); },
      )).toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: cards,
        ),
      )
    );
  }
}

class CurrentServer extends StatelessWidget {
  final UwaveServer server;
  final VoidCallback onOpen;
  final VoidCallback onDisconnect;

  CurrentServer({this.server, this.onOpen, this.onDisconnect});

  @override
  Widget build(_) {
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.headset),
            title: Text(server.name),
            subtitle: const Text('Tap to open'),
            trailing: RaisedButton(
              child: const Text('Disconnect'),
              onPressed: onDisconnect,
            ),
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class ServerCard extends StatelessWidget {
  final UwaveServer server;
  final VoidCallback onJoin;

  ServerCard({this.server, this.onJoin});

  @override
  Widget build(BuildContext context) {
    final thumbnail = <Widget>[];
    thumbnail.add(
      ServerThumbnail(server: server),
    );

    if (server.currentMedia != null) {
      thumbnail.add(
        Container(
          color: Color(0x77000000),
          child: ListTile(
            title: Text(server.currentMedia.title),
            subtitle: Text(server.currentMedia.artist),
          ),
        ),
      );
    }

    final onShowServer = () {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: Text(server.name),
            ),
            body: Markdown(data: server.description),
          );
        },
      ));
    };

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          ListTile(
            title: Text(server.name),
            subtitle: Text(server.subtitle),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onShowServer
            ),
            onTap: onJoin,
          ),
          thumbnail.length == 1
            ? thumbnail
            : Stack(alignment: Alignment.bottomLeft, children: thumbnail),
        ],
      ),
    );
  }
}

class ServerThumbnail extends StatelessWidget {
  final UwaveServer server;

  ServerThumbnail({this.server});

  @override
  Widget build(_) {
    return Hero(
      tag: 'thumb:${server.publicKey}',
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Color(0xFF000000),
          child: server.currentMedia != null
            ? Center(
                child: Image.network(server.currentMedia.thumbnailUrl),
              )
            : null,
        ),
      ),
    );
  }
}
