class Token {
  final String type;
  final String text;
  final String raw;

  Token({this.type, this.text, this.raw});
}

class MarkupNode {}

class TextNode extends MarkupNode {
  final String text;
  TextNode({this.text});

  @override
  String toString() => 'Text($text)';
}

class ItalicNode extends MarkupNode {
  final List<MarkupNode> content;
  ItalicNode({this.content});

  @override
  String toString() => 'Italic(${content.join(', ')})';
}

class BoldNode extends MarkupNode {
  final List<MarkupNode> content;
  BoldNode({this.content});

  @override
  String toString() => 'Bold(${content.join(', ')})';
}

class CodeNode extends MarkupNode {
  final String text;
  CodeNode({this.text});

  @override
  String toString() => 'Code($text)';
}

class StrikeNode extends MarkupNode {
  final List<MarkupNode> content;
  StrikeNode({this.content});

  @override
  String toString() => 'Strike(${content.join(', ')})';
}

class EmojiNode extends MarkupNode {
  final String name;
  EmojiNode({this.name});

  @override
  String toString() => 'Emoji($name)';
}

final emojiPattern = RegExp(r':([A-Za-z0-9_+-]+):');
final spacePattern = RegExp(r'\s+');

class MarkupParser {
  final String source;

  MarkupParser({this.source});

  List<MarkupNode> parse() {
    return _parseChunk(source);
  }

  List<MarkupNode> _parseChunk(String chunk) {
    return _tokenizeChunk(chunk).map((token) {
      switch (token.type) {
        case 'italic': return ItalicNode(content: _parseChunk(token.text));
        case 'bold': return BoldNode(content: _parseChunk(token.text));
        case 'code': return CodeNode(text: token.text);
        case 'strike': return StrikeNode(content: _parseChunk(token.text));
        case 'emoji': return EmojiNode(name: token.text);
        default: return TextNode(text: token.text);
      }
    }).toList();
  }

  List<Token> _tokenizeChunk(String chunk) {
    final tokens = <Token>[];
    int index = 0;

    while (index < chunk.length) {
      final space = spacePattern.matchAsPrefix(chunk, index)?.group(0);
      if (space != null) {
        _addText(tokens, space);
        index += space.length;
        continue;
      }

      final emoji = emojiPattern.matchAsPrefix(chunk, index)?.group(1);
      if (emoji != null) {
        tokens.add(Token(type: 'emoji', text: emoji, raw: ':$emoji:'));
        index += emoji.length + 2;
        continue;
      }

      // final mention = mentionPattern.matchAsPrefix(chunk, index)?.group(0);
      // if (mention != null) {
      //   tokens.add(Token(type: 'mention', text: mention, raw: '@$mention'));
      //   index += mention.length + 1;
      //   continue;
      // }

      if (chunk[index] == '_' && chunk[index + 1] != '_') {
        final end = chunk.indexOf(RegExp(r'_(\W|$)'), index + 1);
        if (end != -1) {
          final text = chunk.substring(index + 1, end);
          tokens.add(Token(type: 'italic', text: text, raw: text));
          index = end + 1;
          continue;
        }
      }

      if (chunk[index] == '*' && chunk[index + 1] != '*') {
        final end = chunk.indexOf(RegExp(r'\*(\W|$)'), index + 1);
        if (end != -1) {
          final text = chunk.substring(index + 1, end);
          tokens.add(Token(type: 'bold', text: text, raw: text));
          index = end + 1;
          continue;
        }
      }

      if (chunk[index] == '`' && chunk[index + 1] != '`') {
        final end = chunk.indexOf(RegExp(r'`(\W|$)'), index + 1);
        if (end != -1) {
          final text = chunk.substring(index + 1, end);
          tokens.add(Token(type: 'code', text: text, raw: text));
          index = end + 1;
          continue;
        }
      }

      if (chunk[index] == '~' && chunk[index + 1] != '~') {
        final end = chunk.indexOf(RegExp(r'~(\W|$)'), index + 1);
        if (end != -1) {
          final text = chunk.substring(index + 1, end);
          tokens.add(Token(type: 'strike', text: text, raw: text));
          index = end + 1;
          continue;
        }
      }

      var end = chunk.indexOf(' ', index + 1);
      if (end == -1) {
        end = chunk.length;
      } else {
        end += 1;
      }

      _addText(tokens, chunk.substring(index, end));
      index = end;
    }

    return tokens;
  }

  void _addText(List<Token> tokens, String text) {
    if (tokens.length > 0 && tokens.last.type == 'text') {
      final concat = '${tokens.last.text}${text}';
      tokens.last = Token(type: 'text', text: concat, raw: concat);
    } else {
      tokens.add(Token(type: 'text', text: text, raw: text));
    }
  }
}
