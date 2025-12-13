import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('Red-Letter Bible Support', () {
    test('parses verse without Jesus quotes (no segments)', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="John">
              <chapter osisID="John.1" n="1">
                <verse osisID="John.1.1" n="1">In the beginning was the Word.</verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      final parser = BibleParser.fromString(xml, format: 'OSIS');
      final verses = await parser.verses.toList();

      expect(verses, hasLength(1));
      expect(verses[0].text, contains('In the beginning was the Word'));
      expect(verses[0].segments, isNull);
      expect(verses[0].hasJesusWords, isFalse);
    });

    test('parses verse with Jesus quote (with segments)', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="John">
              <chapter osisID="John.11" n="11">
                <verse osisID="John.11.34" sID="John.11.34" n="34" />
                And said,
                <q who="Jesus" sID="John.11.34.q1" marker="" />Where have ye laid him?<q eID="John.11.34.q1" />
                They said unto him, Lord, come and see.
                <verse eID="John.11.34" />
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      final parser = BibleParser.fromString(xml, format: 'OSIS');
      final verses = await parser.verses.toList();

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.text, contains('And said'));
      expect(verse.text, contains('Where have ye laid him'));
      expect(verse.text, contains('They said unto him'));

      // Check segments
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(3));

      // First segment: "And said,"
      expect(verse.segments![0].text, 'And said,');
      expect(verse.segments![0].isJesus, isFalse);
      expect(verse.segments![0].speaker, isNull);

      // Second segment: Jesus speaking
      expect(verse.segments![1].text, 'Where have ye laid him?');
      expect(verse.segments![1].isJesus, isTrue);
      expect(verse.segments![1].speaker, 'Jesus');

      // Third segment: Others speaking
      expect(
          verse.segments![2].text, 'They said unto him, Lord, come and see.');
      expect(verse.segments![2].isJesus, isFalse);

      // Check convenience getter
      expect(verse.hasJesusWords, isTrue);
    });

    test('parses verse with only Jesus speaking', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="John">
              <chapter osisID="John.14" n="14">
                <verse osisID="John.14.6" n="6">
                  <q who="Jesus">I am the way, the truth, and the life.</q>
                </verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      final parser = BibleParser.fromString(xml, format: 'OSIS');
      final verses = await parser.verses.toList();

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(1));
      expect(verse.segments![0].isJesus, isTrue);
      expect(verse.hasJesusWords, isTrue);
    });

    test('parses multiple verses with mixed Jesus quotes', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="Matt">
              <chapter osisID="Matt.5" n="5">
                <verse osisID="Matt.5.1" n="1">
                  And seeing the multitudes, he went up into a mountain.
                </verse>
                <verse osisID="Matt.5.2" n="2">
                  And he opened his mouth, and taught them, saying,
                </verse>
                <verse osisID="Matt.5.3" n="3">
                  <q who="Jesus">Blessed are the poor in spirit.</q>
                </verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      final parser = BibleParser.fromString(xml, format: 'OSIS');
      final verses = await parser.verses.toList();

      expect(verses, hasLength(3));

      // First verse: no Jesus words
      expect(verses[0].hasJesusWords, isFalse);
      expect(verses[0].segments, isNull);

      // Second verse: no Jesus words
      expect(verses[1].hasJesusWords, isFalse);
      expect(verses[1].segments, isNull);

      // Third verse: Jesus speaking
      expect(verses[2].hasJesusWords, isTrue);
      expect(verses[2].segments, isNotNull);
      expect(verses[2].segments![0].isJesus, isTrue);
    });

    test('TextSegment equality and toString', () {
      final segment1 = TextSegment(
        text: 'Hello',
        attributes: {'speaker': 'Jesus'},
      );

      final segment2 = TextSegment(
        text: 'Hello',
        attributes: {'speaker': 'Jesus'},
      );

      final segment3 = TextSegment(
        text: 'Hello',
        attributes: null,
      );

      expect(segment1, equals(segment2));
      expect(segment1, isNot(equals(segment3)));
      expect(segment1.toString(), contains('Hello'));
      expect(segment1.toString(), contains('speaker'));
    });
  });
}
