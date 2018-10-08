import 'dart:async' show Stream, StreamSubscription;
import 'package:flutter/material.dart';
import './u_wave/u_wave.dart' show User, ChatMessage, UserJoinMessage, UserLeaveMessage;
import './u_wave/markup.dart' as markup;

class ChatMessages extends StatefulWidget {
  final Stream<dynamic> notifications;
  final Stream<ChatMessage> messages;

  ChatMessages({Key key, this.notifications, this.messages}) : super(key: key);

  @override
  _ChatMessagesState createState() => _ChatMessagesState();
}

class _ChatMessagesState extends State<ChatMessages> {
  final List<dynamic> _messages = [];
  StreamSubscription<ChatMessage> _chatSubscription;
  StreamSubscription<dynamic> _notificationsSubscription;

  static _isSupportedNotification(message) {
    return message is UserJoinMessage ||
        message is UserLeaveMessage;
  }

  @override
  void initState() {
    super.initState();

    _chatSubscription = widget.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
    });
    _notificationsSubscription = widget.notifications.listen((message) {
      setState(() {
        if (_isSupportedNotification(message)) {
          _messages.add(message);
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _chatSubscription.cancel();
    _notificationsSubscription.cancel();
    _chatSubscription = null;
    _notificationsSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF151515),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          if (message is ChatMessage) {
            return ChatMessageView(message);
          }
          if (message is UserJoinMessage) {
            return UserJoinMessageView(message);
          }
          if (message is UserLeaveMessage) {
            return UserLeaveMessageView(message);
          }
          return Text('Unexpected message type!');
        },
      ),
    );
  }
}

typedef OnSendCallback = void Function(String);
class ChatInput extends StatefulWidget {
  final User user;
  final OnSendCallback onSend;

  ChatInput({this.user, this.onSend});

  @override
  _ChatInputState createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  static const _PADDING = 6.0;

  final _editController = TextEditingController();

  void _submit() {
    widget.onSend(_editController.text);
    _editController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF1B1B1B),
      child: Padding(
        padding: const EdgeInsets.all(_PADDING),
        child: Row(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: _PADDING),
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.user.avatarUrl),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _editController,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class UserJoinMessageView extends StatelessWidget {
  final UserJoinMessage message;

  UserJoinMessageView(this.message);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );
    final username = message.user?.username ?? '<unknown>';

    return ListTile(
      dense: true,
      leading: avatar,
      title: Text('$username joined', style: TextStyle(color: Color(0xFFAAAAAA))),
    );
  }
}

class UserLeaveMessageView extends StatelessWidget {
  final UserLeaveMessage message;

  UserLeaveMessageView(this.message);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );
    final username = message.user?.username ?? '<unknown>';

    return ListTile(
      dense: true,
      leading: avatar,
      title: Text('$username left', style: TextStyle(color: Color(0xFFAAAAAA))),
    );
  }
}

class ChatMessageView extends StatelessWidget {
  final ChatMessage message;

  ChatMessageView(this.message);

  @override
  Widget build(_) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );

    return ListTile(
      dense: true,
      leading: avatar,
      title: Text(message.user?.username ?? '<unknown>'),
      subtitle: MarkupSpan(tree: message.parsedMessage),
    );
  }
}

class MarkupSpan extends StatelessWidget {
  final List<markup.MarkupNode> tree;

  MarkupSpan({Key key, this.tree}) : super(key: key);

  TextSpan _toTextSpan(markup.MarkupNode node) {
    if (node is markup.BoldNode) {
      return TextSpan(
        children: node.content.map(_toTextSpan).toList(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    if (node is markup.ItalicNode) {
      return TextSpan(
        children: node.content.map(_toTextSpan).toList(),
        style: const TextStyle(fontStyle: FontStyle.italic),
      );
    }
    if (node is markup.StrikeNode) {
      return TextSpan(
        children: node.content.map(_toTextSpan).toList(),
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      );
    }
    if (node is markup.CodeNode) {
      return TextSpan(
        text: node.text,
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }
    if (node is markup.EmojiNode) {
      return TextSpan(
        text: node.name,
        style: const TextStyle(color: Color(0xFFFF0000)),
      );
    }
    if (node is markup.TextNode) {
      return TextSpan(text: node.text);
    }
    throw 'Unsupported node type';
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: tree.map(_toTextSpan).toList(),
      ),
    );
  }
}
