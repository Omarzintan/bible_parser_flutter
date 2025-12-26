import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/src/parsers/usfx_parser.dart';
import 'package:bible_parser_flutter/src/text_segment.dart';

void main() {
  group('USFX Add Tag Support Tests', () {
    test('should parse add tag for added/italicized text', () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="GEN">
    <c id="1" />
    <v id="2" />And the earth was without form, and void; and darkness <add>was</add> upon the face of the deep.
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final verses = await parser.parseVerses().toList();

      expect(verses.length, 1);
      final verse = verses[0];

      // Check that segments were created
      expect(verse.segments, isNotNull);
      expect(verse.segments!.length, greaterThan(1));

      // Find the segment with transChange attribute
      final addedSegment = verse.segments!.firstWhere(
        (seg) => seg.isAdded,
        orElse: () => TextSegment(text: ''),
      );

      expect(addedSegment.text, 'was');
      expect(addedSegment.transChange, 'added');
      expect(addedSegment.isAdded, true);
    });

    test('should handle multiple add tags in one verse', () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="GEN">
    <c id="1" />
    <v id="3" />And God said, Let there <add>be</add> light: and there <add>was</add> light.
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final verses = await parser.parseVerses().toList();

      expect(verses.length, 1);
      final verse = verses[0];

      expect(verse.segments, isNotNull);

      // Find all added segments
      final addedSegments =
          verse.segments!.where((seg) => seg.isAdded).toList();

      expect(addedSegments.length, 2);
      expect(addedSegments[0].text, 'be');
      expect(addedSegments[0].isAdded, true);
      expect(addedSegments[1].text, 'was');
      expect(addedSegments[1].isAdded, true);
    });

    test('should handle add tag within Jesus words', () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="JHN">
    <c id="3" />
    <v id="16" />
    <wj>For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have <add>everlasting</add> life.</wj>
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final verses = await parser.parseVerses().toList();

      expect(verses.length, 1);
      final verse = verses[0];

      expect(verse.segments, isNotNull);

      // Find the segment with both Jesus and added attributes
      final jesusAddedSegment = verse.segments!.firstWhere(
        (seg) => seg.isJesus && seg.isAdded,
        orElse: () => TextSegment(text: ''),
      );

      expect(jesusAddedSegment.text, contains('everlasting'));
      expect(jesusAddedSegment.isJesus, true);
      expect(jesusAddedSegment.isAdded, true);
      expect(jesusAddedSegment.speaker, 'Jesus');
      expect(jesusAddedSegment.transChange, 'added');
    });

    test('should preserve full verse text while tracking add segments',
        () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="GEN">
    <c id="1" />
    <v id="2" />And the earth was without form, and void; and darkness <add>was</add> upon the face of the deep.
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final verses = await parser.parseVerses().toList();

      final verse = verses[0];

      // Full text should still be preserved
      expect(verse.text, contains('And the earth was without form'));
      expect(verse.text, contains('was'));
      expect(verse.text, contains('upon the face of the deep'));
    });

    test('should handle verse without add tags - no segments', () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="GEN">
    <c id="1" />
    <v id="1" />In the beginning God created the heaven and the earth.
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final verses = await parser.parseVerses().toList();

      expect(verses.length, 1);
      final verse = verses[0];

      expect(verse.text, contains('In the beginning God created'));
      expect(verse.segments, isNull);
    });

    test('parseBooks should also create add segments', () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="GEN">
    <c id="1" />
    <v id="2" />And the earth was without form, and void; and darkness <add>was</add> upon the face of the deep.
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final books = await parser.parseBooks().toList();

      expect(books, hasLength(1));

      final book = books[0];
      expect(book.chapters, hasLength(1));

      final chapter = book.chapters[0];
      expect(chapter.verses, hasLength(1));

      final verse = chapter.verses[0];
      expect(verse.segments, isNotNull);

      final addedSegment = verse.segments!.firstWhere(
        (seg) => seg.isAdded,
        orElse: () => TextSegment(text: ''),
      );

      expect(addedSegment.text, 'was');
      expect(addedSegment.isAdded, true);
    });

    test('should handle nested add tags with other elements', () async {
      const usfxXml = '''
<?xml version="1.0" encoding="utf-8"?>
<usfx>
  <book id="GEN">
    <c id="1" />
    <v id="2" />And the <w s="H0776">earth</w> <add>was</add> without form.
    <ve />
  </book>
</usfx>
''';

      final parser = UsfxParser(usfxXml);
      final verses = await parser.parseVerses().toList();

      expect(verses.length, 1);
      final verse = verses[0];

      expect(verse.segments, isNotNull);

      final addedSegment = verse.segments!.firstWhere(
        (seg) => seg.isAdded,
        orElse: () => TextSegment(text: ''),
      );

      expect(addedSegment.text, 'was');
      expect(addedSegment.isAdded, true);
      expect(verse.text, contains('earth'));
      expect(verse.text, contains('was'));
      expect(verse.text, contains('without form'));
    });
  });
}
