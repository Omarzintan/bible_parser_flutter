import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('USFX Red-Letter Support', () {
    test('parses verses with Jesus words using wj tags', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="8"/>
    <v id="33"/>Then Jesus said,
<wj>"I will be with you a little while longer, then I go to him who sent me.
</wj>
<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.text, contains('Then Jesus said'));
      expect(verse.text, contains('I will be with you'));

      // Check segments
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(2));

      // First segment: "Then Jesus said,"
      expect(verse.segments![0].text, 'Then Jesus said,');
      expect(verse.segments![0].isJesus, isFalse);

      // Second segment: Jesus speaking
      expect(verse.segments![1].text, contains('I will be with you'));
      expect(verse.segments![1].isJesus, isTrue);
      expect(verse.segments![1].speaker, 'Jesus');

      expect(verse.hasJesusWords, isTrue);
    });

    test('parses verses without wj tags - no segments', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="1"/>
    <v id="1"/>In the beginning was the Word.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.text, contains('In the beginning was the Word'));
      expect(verse.segments, isNull);
      expect(verse.hasJesusWords, isFalse);
    });

    test('parses verses with only Jesus speaking', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="14"/>
    <v id="6"/>
<wj>I am the way, the truth, and the life.</wj>
<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(1));
      expect(verse.segments![0].isJesus, isTrue);
      expect(verse.segments![0].text, 'I am the way, the truth, and the life.');
      expect(verse.hasJesusWords, isTrue);
    });

    test('parses multiple verses with mixed Jesus quotes', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="8"/>
    <v id="31"/>Then said Jesus to those Jews which believed on him,
<wj>If ye continue in my word, then are ye my disciples indeed;</wj>
<ve/>
    <v id="32"/>
<wj>And ye shall know the truth, and the truth shall make you free.</wj>
<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();

      expect(verses, hasLength(2));

      // First verse: mixed
      expect(verses[0].segments, isNotNull);
      expect(verses[0].segments, hasLength(2));
      expect(verses[0].segments![0].isJesus, isFalse);
      expect(verses[0].segments![1].isJesus, isTrue);
      expect(verses[0].hasJesusWords, isTrue);

      // Second verse: only Jesus
      expect(verses[1].segments, isNotNull);
      expect(verses[1].segments, hasLength(1));
      expect(verses[1].segments![0].isJesus, isTrue);
      expect(verses[1].hasJesusWords, isTrue);
    });

    test('parseBooks also creates segments', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="14"/>
    <v id="6"/>
<wj>I am the way, the truth, and the life.</wj>
<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final books = await parser.parseBooks().toList();

      expect(books, hasLength(1));

      final book = books[0];
      expect(book.chapters, hasLength(1));

      final chapter = book.chapters[0];
      expect(chapter.verses, hasLength(1));

      final verse = chapter.verses[0];
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(1));
      expect(verse.segments![0].isJesus, isTrue);
      expect(verse.hasJesusWords, isTrue);
    });
  });
}
