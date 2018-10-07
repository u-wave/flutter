import 'package:flutter/material.dart';
import './u_wave/announce.dart' show UwaveServer;
import './server_list.dart' show UwaveServerList;
import './listen.dart' show UwaveListen;

void main() => runApp(UwaveApp());

class UwaveApp extends StatelessWidget {
  // This widget is the root of your application.
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
        onJoin: (context, server) =>  _listen(context, server),
      ),
    );
  }

  void _listen(BuildContext context, UwaveServer server) {
    Navigator.push(context, MaterialPageRoute(
      maintainState: false,
      builder: (context) => UwaveListen(server: server),
    ));
  }
}
