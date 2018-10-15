// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester utility that Flutter
// provides. For example, you can send tap and scroll gestures. You can also use WidgetTester to
// find child widgets in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:uw_flutter/u_wave/markup.dart';

void main() {
  test('bold', () {
    expect(MarkupParser(source: 'some *bold* text').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'some '),
      BoldNode(content: <MarkupNode>[
        TextNode(text: 'bold'),
      ]),
      TextNode(text: ' text'),
    ].join(', ')));
  });

  test('italic', () {
    expect(MarkupParser(source: 'some _italic_ text').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'some '),
      ItalicNode(content: <MarkupNode>[
        TextNode(text: 'italic'),
      ]),
      TextNode(text: ' text'),
    ].join(', ')));
  });

  test('strike', () {
    expect(MarkupParser(source: 'some ~stroke~ text').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'some '),
      StrikeNode(content: <MarkupNode>[
        TextNode(text: 'stroke'),
      ]),
      TextNode(text: ' text'),
    ].join(', ')));
  });

  test('code', () {
    expect(MarkupParser(source: 'some `monospace` text').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'some '),
      CodeNode(text: 'monospace'),
      TextNode(text: ' text'),
    ].join(', ')));
  });

  test('markup characters in the middle of a word', () {
    expect(MarkupParser(source: 'underscored_words are fun_!').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'underscored_words are fun_!'),
    ].join(', ')));
  });

  test('stray markup characters', () {
    expect(MarkupParser(source: 'a * b').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'a * b'),
    ].join(', ')));
  });

  test('nested',  () {
    expect(MarkupParser(source: '*bold _italic_*').parse().join(', '), equals(<MarkupNode>[
      BoldNode(content: <MarkupNode>[
        TextNode(text: 'bold '),
        ItalicNode(content: <MarkupNode>[
          TextNode(text: 'italic'),
        ]),
      ]),
    ].join(', ')));
  });

  test('code nested inside markup', () {
    expect(MarkupParser(source: '*_`monospace`_*').parse().join(', '), equals(<MarkupNode>[
      BoldNode(content: <MarkupNode>[
        ItalicNode(content: <MarkupNode>[
          CodeNode(text: 'monospace'),
        ]),
      ]),
    ].join(', ')));
  });

  test('markup nested inside code', () {
    expect(MarkupParser(source: 'a `b *c* _d_` e').parse().join(', '), equals(<MarkupNode>[
      TextNode(text: 'a '),
      CodeNode(text: 'b *c* _d_'),
      TextNode(text: ' e'),
    ].join(', ')));
  });

  test('Markup', () {
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
