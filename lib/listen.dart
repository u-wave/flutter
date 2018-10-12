import 'dart:async';
import 'package:flutter/material.dart';
import './u_wave/announce.dart' show UwaveServer;
import './u_wave/u_wave.dart';
import './server_list.dart' show ServerThumbnail;
import './playback_settings.dart' show PlaybackSettingsRoute;
import './signin_views.dart' show SignInRoute;
import './chat_views.dart' show ChatMessages, ChatInput;
import './listen_store.dart' show ListenStore;
import './player.dart' show ProgressTimer;

class UwaveListen extends StatefulWidget {
  final UwaveServer server;
  final ListenStore store;

  UwaveListen({Key key, this.server, this.store}) : super(key: key);

  @override
  _UwaveListenState createState() => _UwaveListenState();
}

class _UwaveListenState extends State<UwaveListen> {
  final _playerViewKey = GlobalKey<_UwaveListenState>();
  StreamSubscription<Null> _updateSubscription;
  bool _clientConnected = false;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();

    _updateSubscription = widget.store.onUpdate.listen((_) {
      setState(() {
        debugPrint('rerendering...');
        // Just rerender
      });
    });

    widget.store.connect(widget.server).then((_) {
      setState(() {
        _clientConnected = true;
      });
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // Reconnect.
    widget.store.disconnect();
    widget.store.connect(widget.server);
  }

  @override
  void dispose() {
    super.dispose();
    _updateSubscription.cancel();
    _updateSubscription = null;
  }

  Future<Null> _showSignInPage() async {
    await Navigator.push(context, MaterialPageRoute(
      maintainState: true,
      builder: (context) => SignInRoute(
        uwave: widget.store.uwaveClient,
        onComplete: (creds) {
          if (creds != null) {
            widget.store.saveCredentials(creds);
          }
          Navigator.pop(context);
        },
      ),
    ));
  }

  void _signIn() {
    _showSignInPage().then((_) {
      setState(() { /* rerender based on _client.currentUser */ });
    });
  }

  void _sendChat(String message) {
    widget.store.sendChat(message);
  }

  void _onTapDown(BuildContext context, TapDownDetails details) {
    final RenderBox playerBox = _playerViewKey.currentContext.findRenderObject();
    final tapPosition = playerBox.globalToLocal(details.globalPosition);
    final shouldShow = playerBox.paintBounds.contains(tapPosition);

    if (_showOverlay != shouldShow) {
      setState(() {
        _showOverlay = shouldShow;
      });
    }
  }

  void _onOpenPlaybackSettings() {
    Navigator.push(context, MaterialPageRoute(
      maintainState: true,
      builder: (_) => PlaybackSettingsRoute(),
    ));
  }

  Widget _buildVoteButtons() {
    final voteStats = widget.store.voteStats;
    final currentUser = widget.store.currentUser;
    final didUpvote = voteStats?.didUpvote(currentUser);
    final didFavorite = voteStats?.didFavorite(currentUser);
    final didDownvote = voteStats?.didDownvote(currentUser);

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(
              Icons.thumb_up,
              color: didUpvote ? const Color(0xFF4BB64B) : Colors.white,
            ),
            onPressed: () {
              final client = widget.store.uwaveClient;
              client.upvote();
            },
          ),
          FavoriteButton(active: didFavorite),
          IconButton(
            icon: Icon(
              Icons.thumb_down,
              color: didDownvote ? const Color(0xFFB64B4B) : Colors.white,
            ),
            onPressed: () {
              final client = widget.store.uwaveClient;
              client.downvote();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsIcon() {
    return Positioned(
      top: 8.0,
      right: 8.0,
      child: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: _onOpenPlaybackSettings,
      ),
    );
  }

  Widget _buildPlayerOverlay() {
    final List<Widget> children = [];
    if (widget.store.isSignedIn) {
      children.add(_buildVoteButtons());
    }
    children.add(_buildSettingsIcon());

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Color(0x77000000),
        child: Stack(children: children),
      ),
    );
  }

  Widget _buildPlayer() {
    if (widget.store.isPlaying) {
      final children = <Widget>[
        PlayerView(
          textureId: widget.store.playbackSettings.texture,
          aspectRatio: widget.store.playbackSettings.aspectRatio,
          entry: widget.store.currentEntry,
          currentProgress: widget.store.playbackSettings.onProgress,
        ),
      ];

      if (_showOverlay) {
        children.add(_buildPlayerOverlay());
      }

      return Stack(
        key: _playerViewKey,
        children: children,
      );
    }
    if (_clientConnected) {
      // nobody playing right now
      return Container();
    }
    // still loading
    // TODO add loading spinner overlay using a Stack widget
    return ServerThumbnail(server: widget.server);
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = ChatMessages(
      messages: widget.store.chatHistory,
    );

    final Widget footer = widget.store.isSignedIn
      ? ChatInput(user: widget.store.currentUser, onSend: _sendChat)
      : SignInButton(serverName: widget.server.name, onSignIn: _signIn);

    return Scaffold(
      appBar: AppBar(
        title: widget.store.currentEntry == null
          ? Text(widget.server.name)
          : CurrentMediaTitle(artist: widget.store.currentEntry.artist, title: widget.store.currentEntry.title),
      ),
      body: GestureDetector(
        onTapDown: (details) => _onTapDown(context, details),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Flexible(flex: 0, child: _buildPlayer()),
                  Expanded(flex: 1, child: chatMessages),
                ],
              )
            ),
            footer,
          ],
        ),
      ),
    );
  }
}

class PlayerView extends StatelessWidget {
  final int textureId;
  final HistoryEntry entry;
  final ProgressTimer currentProgress;
  final double aspectRatio;

  PlayerView({this.textureId, this.entry, this.currentProgress, this.aspectRatio = 16 / 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF000000),
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: textureId == null
                ? Image.network(entry.media.thumbnailUrl)
                : AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Texture(textureId: textureId,
                  )),
            ),
          ),
          MediaProgressBar(
            currentProgress: currentProgress,
            duration: Duration(seconds: entry.end - entry.start),
          ),
        ],
      ),
    );
  }
}

class MediaProgressBar extends StatelessWidget {
  final ProgressTimer currentProgress;
  final Duration duration;

  MediaProgressBar({this.currentProgress, this.duration});

  @override
  Widget build(_) {
    return StreamBuilder<Duration>(
      stream: currentProgress.stream,
      builder: (_, snapshot) {
        Duration progress = const Duration(seconds: 0);
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            progress = currentProgress.current;
            break;
          case ConnectionState.active:
            progress = snapshot.data;
            break;
          case ConnectionState.done:
            progress = duration;
            break;
        }
        return LinearProgressIndicator(
          value: progress.inSeconds / duration.inSeconds,
        );
      },
    );
  }
}

class SignInButton extends StatelessWidget {
  final String serverName;
  final VoidCallback onSignIn;

  SignInButton({this.serverName, this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FlatButton(
              color: Theme.of(context).primaryColor,
              textTheme: ButtonTextTheme.primary,
              child: Text('Sign In to $serverName'),
              onPressed: onSignIn,
            ),
          ),
        ),
      ],
    );
  }
}

class CurrentMediaTitle extends StatelessWidget {
  final String artist;
  final String title;

  CurrentMediaTitle({ this.artist, this.title });

  @override
  Widget build(BuildContext context) {
    return RichText(
      softWrap: false,
      overflow: TextOverflow.fade,
      text: TextSpan(
        style: Theme.of(context).primaryTextTheme.title,
        children: <TextSpan>[
          TextSpan(text: artist),
          const TextSpan(text: ' – '),
          TextSpan(
            text: title,
            style: TextStyle(color: Colors.white.withOpacity(0.7),
          )),
        ],
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  final bool active;

  FavoriteButton({this.active});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        active ? Icons.favorite : Icons.favorite_border,
        color: const Color(0xFF9D2053),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => BottomSheet(
            onClosing: () {},
            builder: (_) => ListView(
              children: <Widget>[
                ListTile(title: Text('Free-For-All Fridays')),
                ListTile(title: Text('K-Indie')),
                ListTile(title: Text('K-Pop')),
              ],
            ),
          ),
        );
      },
    );
  }
}
