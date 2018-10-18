import 'package:flutter/material.dart';
import './u_wave/u_wave.dart' show User, ChatMessage, UserJoinMessage, UserLeaveMessage;
import './u_wave/markup.dart' as markup;

class ChatMessages extends StatelessWidget {
  final List<dynamic> messages;

  ChatMessages({Key key, this.messages})
      : assert(messages != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF151515),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          if (message is ChatMessage) {
            return ChatMessageView(message);
          }
          if (message is UserJoinMessage) {
            return UserJoinMessageView(message);
          }
          if (message is UserLeaveMessage) {
            return UserLeaveMessageView(message);
          }
          return Text(
            'Unexpected message type!',
            style: TextStyle(color: Color(0xFFFF0000)),
          );
        },
      ),
    );
  }
}

typedef OnSendCallback = void Function(String);
class ChatInput extends StatefulWidget {
  final User user;
  final OnSendCallback onSend;

  ChatInput({this.user, this.onSend}) : assert(user != null), assert(onSend != null);

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

  UserJoinMessageView(this.message) : assert(message != null);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          radius: 12.0,
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          radius: 12.0,
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );

    return ChatTile(
      sender: message.user,
      leading: avatar,
      child: Text('joined the room', style: TextStyle(color: Color(0xFFAAAAAA))),
    );
  }
}

class UserLeaveMessageView extends StatelessWidget {
  final UserLeaveMessage message;

  UserLeaveMessageView(this.message) : assert(message != null);

  @override
  Widget build(BuildContext context) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          radius: 12.0,
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          radius: 12.0,
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );

    return ChatTile(
      sender: message.user,
      leading: avatar,
      child: Text('left the room', style: TextStyle(color: Color(0xFFAAAAAA))),
    );
  }
}

class ChatTile extends StatelessWidget {
  ChatTile({
    this.sender,
    this.leading,
    this.child,
  }) : assert(sender != null), assert(leading != null), assert(child != null);

  final User sender;
  final Widget leading;
  final Widget child;

  @override
  Widget build(_) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: leading,
          ),
          // This Expanded() instances makes sure the text fills at most the rest
          // of the horizontal space, rather than going over it.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DefaultTextStyle(
                  child: UsernameView(user: sender),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageView extends StatelessWidget {
  final ChatMessage message;

  ChatMessageView(this.message) : assert(message != null);

  @override
  Widget build(_) {
    final avatar = message.user?.avatarUrl != null
      ? CircleAvatar(
          radius: 12.0,
          backgroundImage: NetworkImage(message.user.avatarUrl),
        )
      : CircleAvatar(
          radius: 12.0,
          backgroundColor: Colors.pink.shade800,
          child: Text('UK'),
        );

    return ChatTile(
      sender: message.user,
      leading: avatar,
      child: MarkupSpan(tree: message.parsedMessage),
    );
  }
}

class MarkupSpan extends StatelessWidget {
  final List<markup.MarkupNode> tree;

  MarkupSpan({Key key, this.tree}) : assert(tree != null), super(key: key);

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
    return Text.rich(
      TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: tree.map(_toTextSpan).toList(),
      ),
    );
  }
}

class UsernameView extends StatelessWidget {
  static Map<String, Color> _roleColors = {
    'admin': Color(0xFFFF3B74),
    'manager': Color(0xFF05DAA5),
    'moderator': Color(0xFF00B3DC),
    'special': Color(0xFFFC911D),
  };

  final User user;

  UsernameView({this.user}) : assert(user != null);

  @override
  Widget build(_) {
    final colorRole = user.roles.firstWhere((name) => _roleColors.containsKey(name));
    final color = colorRole != null ? _roleColors[colorRole] : null;

    return Text(user.username,
      style: color != null ? TextStyle(color: color) : null,
    );
  }
}
