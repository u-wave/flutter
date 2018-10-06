import 'package:flutter/material.dart';
import './uwave_announce.dart';

typedef OnJoinCallback = void Function(BuildContext, UwaveServer);

class UwaveServerList extends StatefulWidget {
  final String title;
  final OnJoinCallback onJoin;

  UwaveServerList({Key key, this.title, this.onJoin}) : super(key: key);

  @override
  _UwaveServerListState createState() => new _UwaveServerListState();
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
    widget.onJoin(context, server);
  }

  @override
  void initState() {
    super.initState();
    this._updateServers();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          child: Column(
            children:
                _servers.map<Widget>((server) => _renderServer(server)).toList(),
          ),
        ),
      )
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
