// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester utility that Flutter
// provides. For example, you can send tap and scroll gestures. You can also use WidgetTester to
// find child widgets in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:uw_flutter/u_wave/markup.dart';

void main() {
  test('Markup', () async {
    List<MarkupNode> parts = MarkupParser(source: '*bold* _italic_').parse();
    expect(parts[0], isInstanceOf<BoldNode>());
    expect(parts[1], isInstanceOf<TextNode>());
    expect(parts[2], isInstanceOf<ItalicNode>());

    parts = MarkupParser(source: ':bdance: :smile:~strike~').parse();
    expect(parts[0], isInstanceOf<EmojiNode>());
    expect(parts[1], isInstanceOf<TextNode>());
    expect(parts[2], isInstanceOf<EmojiNode>());
    expect(parts[3], isInstanceOf<StrikeNode>());

    parts = MarkupParser(source: '*bold* `code *notbold*`').parse();
    expect(parts[0], isInstanceOf<BoldNode>());
    expect(parts[1], isInstanceOf<TextNode>());
    expect(parts[2], isInstanceOf<CodeNode>());
    expect((parts[2] as CodeNode).text, equals('code *notbold*'));
  });
}
