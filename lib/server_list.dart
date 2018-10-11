import 'package:flutter/material.dart';
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
  UwaveAnnounceClient _client = UwaveAnnounceClient();
  List<UwaveServer> _servers = List();

  void _updateServers() {
    _client.fetchServers();
  }

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
    _client.onUpdate = (_) {
      setState(() {
        _servers = _client.servers.toList();
      });
    };
  }

  void reassemble() {
    super.reassemble();
    this._updateServers();
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
            title: Text('Connected to ${server.name}'),
          ),
          ButtonTheme.bar(
            child: ButtonBar(
              children: [
                FlatButton(
                  child: const Text('Disconnect'),
                  onPressed: onDisconnect,
                ),
                FlatButton(
                  child: const Text('Open'),
                  onPressed: onOpen,
                ),
              ],
            ),
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
  Widget build(_) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          ListTile(
            title: Text(server.name),
            subtitle: Text(server.subtitle),
            trailing: const Icon(Icons.more_vert),
            onTap: onJoin,
          ),
          ServerThumbnail(server: server),
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
        child: Center(
          child: server.currentMedia != null
            ? Image.network(server.currentMedia.thumbnailUrl)
            : Container(color: Color(0xFF000000)),
        ),
      ),
    );
  }
}
