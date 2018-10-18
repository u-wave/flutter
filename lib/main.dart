import 'package:flutter/material.dart';
import './u_wave/announce.dart' show UwaveServer;
import './server_list.dart' show UwaveServerList;
import './listen.dart' show UwaveListen;
import './settings.dart' show Settings, UwaveSettings;
import './listen_store.dart' show ListenStore;

void main() async {
  final settings = await Settings.load();
  final listenStore = ListenStore(settings: settings);

  runApp(UwaveSettings(
    settings: settings,
    child: UwaveApp(
      listenStore: listenStore,
    ),
  ));
}

class UwaveApp extends StatelessWidget {
  final ListenStore listenStore;

  UwaveApp({this.listenStore}) : assert(listenStore != null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'üWave',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF9D2053),
        accentColor: Color(0xFFB20062),
      ),
      home: UwaveServerList(
        title: 'Public üWave Servers',
        listenStore: listenStore,
        onJoin: (context, server) =>  _listen(context, server),
      ),
    );
  }

  void _listen(BuildContext context, UwaveServer server) {
    Navigator.push(context, MaterialPageRoute(
      maintainState: false,
      builder: (context) => UwaveListen(
        server: server,
        store: listenStore,
      ),
    ));
  }
}
