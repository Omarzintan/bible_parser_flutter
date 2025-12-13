import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/src/parsers/osis_parser.dart';
import 'package:bible_parser_flutter/src/text_segment.dart';

void main() {
  group('TransChange Support Tests', () {
    test('should parse transChange type="added" attribute from OSIS', () async {
      // Sample OSIS XML with transChange tag
      const osisXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="KJV" osisRefWork="bible" xml:lang="en">
    <div type="book" osisID="Matt">
      <chapter osisID="Matt.27" sID="Matt.27" n="27" />
      <verse osisID="Matt.27.65" sID="Matt.27.65" n="65" />
      Pilate said unto them, Ye have a watch: go your way, make
      <transChange type="added">it</transChange> as sure as ye can.
      <verse eID="Matt.27.65" />
      <chapter eID="Matt.27" />
    </div>
  </osisText>
</osis>
''';

      final parser = OsisParser(osisXml);
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

      expect(addedSegment.text, 'it');
      expect(addedSegment.transChange, 'added');
      expect(addedSegment.isAdded, true);
    });

    test('should handle transChange within Jesus quotes', () async {
      // Sample OSIS XML with both quote and transChange tags
      const osisXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="KJV" osisRefWork="bible" xml:lang="en">
    <div type="book" osisID="John">
      <chapter osisID="John.3" sID="John.3" n="3" />
      <verse osisID="John.3.16" sID="John.3.16" n="16" />
      For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have
      <transChange type="added">everlasting</transChange> life.
      <verse eID="John.3.16" />
      <chapter eID="John.3" />
    </div>
  </osisText>
</osis>
''';

      final parser = OsisParser(osisXml);
      final verses = await parser.parseVerses().toList();

      expect(verses.length, 1);
      final verse = verses[0];

      expect(verse.segments, isNotNull);

      // Find the added segment
      final addedSegment = verse.segments!.firstWhere(
        (seg) => seg.isAdded,
        orElse: () => TextSegment(text: ''),
      );

      expect(addedSegment.text, 'everlasting');
      expect(addedSegment.isAdded, true);
    });

    test('should preserve full verse text while tracking segments', () async {
      const osisXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="KJV" osisRefWork="bible" xml:lang="en">
    <div type="book" osisID="Matt">
      <chapter osisID="Matt.27" sID="Matt.27" n="27" />
      <verse osisID="Matt.27.65" sID="Matt.27.65" n="65" />
      Pilate said unto them, Ye have a watch: go your way, make
      <transChange type="added">it</transChange> as sure as ye can.
      <verse eID="Matt.27.65" />
      <chapter eID="Matt.27" />
    </div>
  </osisText>
</osis>
''';

      final parser = OsisParser(osisXml);
      final verses = await parser.parseVerses().toList();

      final verse = verses[0];

      // Full text should still be preserved
      expect(verse.text, contains('Pilate said unto them'));
      expect(verse.text, contains('it'));
      expect(verse.text, contains('as sure as ye can'));
    });

    test('TextSegment.isAdded should be false for non-added segments', () {
      final normalSegment = TextSegment(
        text: 'normal text',
        attributes: null,
      );

      expect(normalSegment.isAdded, false);
      expect(normalSegment.transChange, null);

      final jesusSegment = TextSegment(
        text: 'Jesus words',
        attributes: {'speaker': 'Jesus'},
      );

      expect(jesusSegment.isAdded, false);
      expect(jesusSegment.isJesus, true);
    });
  });
}
