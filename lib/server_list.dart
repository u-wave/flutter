import 'package:flutter/material.dart';
import './uwave.dart';

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
