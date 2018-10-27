import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' show Markdown;
import './u_wave/announce.dart';
import './listen_store.dart' show ListenStore;

typedef OnJoinCallback = void Function(BuildContext, UwaveServer);

class UwaveServerList extends StatefulWidget {
  /// App title.
  final String title;
  /// Function to call when the user wants to join a server.
  final OnJoinCallback onJoin;
  /// Listening state manager.
  final ListenStore listenStore;

  const UwaveServerList({Key key, this.title, this.onJoin, this.listenStore})
      : assert(title != null),
        assert(onJoin != null),
        assert(listenStore != null),
        super(key: key);

  @override
  _UwaveServerListState createState() => _UwaveServerListState();
}

class _UwaveServerListState extends State<UwaveServerList> {
  UwaveAnnounceClient _client;
  List<UwaveServer> _servers = [];

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

  @override
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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: cards,
      ),
    );
  }
}

class CurrentServer extends StatelessWidget {
  /// The server to show in this tile.
  final UwaveServer server;
  /// Called when the tile is tapped.
  final VoidCallback onOpen;
  /// Called when the "Disconnect" button is tapped.
  final VoidCallback onDisconnect;

  const CurrentServer({this.server, this.onOpen, this.onDisconnect})
      : assert(server != null),
        assert(onOpen != null),
        assert(onDisconnect != null);

  @override
  Widget build(_) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.headset),
        title: Text(server.name),
        subtitle: const Text('Tap to open'),
        trailing: RaisedButton(
          child: const Text('Disconnect'),
          onPressed: onDisconnect,
        ),
        onTap: onOpen,
      ),
    );
  }
}

class ServerCard extends StatelessWidget {
  /// The server to show in this card.
  final UwaveServer server;
  /// Called when the server card is tapped, indicating that the user wants to join this server.
  final VoidCallback onJoin;

  const ServerCard({this.server, this.onJoin})
      : assert(server != null),
        assert(onJoin != null);

  @override
  Widget build(BuildContext context) {
    final thumbnail = <Widget>[];
    thumbnail.add(
      ServerThumbnail(server: server),
    );

    if (server.currentMedia != null) {
      thumbnail.add(
        Container(
          color: const Color(0x77000000),
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
          return DescriptionPage(server: server);
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
            ? thumbnail.first
            : Stack(alignment: Alignment.bottomLeft, children: thumbnail),
        ],
      ),
    );
  }
}

class ServerThumbnail extends StatelessWidget {
  /// The server to show.
  final UwaveServer server;

  const ServerThumbnail({this.server})
      : assert(server != null);

  @override
  Widget build(_) {
    return Hero(
      tag: 'thumb:${server.publicKey}',
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: const Color(0xFF000000),
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

class DescriptionPage extends StatelessWidget {
  /// The server to show a description for.
  final UwaveServer server;

  const DescriptionPage({this.server})
      : assert(server != null);

  @override
  Widget build(_) {
    return Scaffold(
      appBar: AppBar(
        title: Text(server.name),
      ),
      body: Markdown(data: server.description),
    );
  }
}
