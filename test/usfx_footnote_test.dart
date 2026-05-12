import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('USFX Footnote Support', () {
    test('parses a verse with a single footnote', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>In the beginning<f id="f1">Hebrew: bereshit</f> God created the heavens and the earth.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();

      expect(verses, hasLength(1));
      final verse = verses[0];

      // Verse text should not contain footnote content
      expect(verse.text, contains('In the beginning'));
      expect(verse.text, contains('God created'));
      expect(verse.text, isNot(contains('bereshit')));

      // Footnotes should be present
      expect(verse.hasFootnotes, isTrue);
      expect(verse.footnotes, hasLength(1));
      expect(verse.footnotes![0].id, 'f1');
      expect(verse.footnotes![0].marker, '¹');
      expect(verse.footnotes![0].content, 'Hebrew: bereshit');
    });

    test('footnote marker segment is present in segments at correct position',
        () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>In the beginning<f id="f1">Hebrew: bereshit</f> God created the heavens.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();
      final verse = verses[0];

      // Segments should be populated (footnote triggers hasQuoteTags)
      expect(verse.segments, isNotNull);

      // One segment before the footnote, one marker, one segment after
      final markerSegments =
          verse.segments!.where((s) => s.isFootnoteMarker).toList();
      expect(markerSegments, hasLength(1));
      expect(markerSegments[0].footnoteId, 'f1');
      expect(markerSegments[0].text, '');
    });

    test('parses multiple footnotes with incrementing markers', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>In the beginning<f id="f1">Hebrew: bereshit</f> God<f id="f2">Hebrew: Elohim</f> created.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();
      final verse = verses[0];

      expect(verse.hasFootnotes, isTrue);
      expect(verse.footnotes, hasLength(2));

      expect(verse.footnotes![0].id, 'f1');
      expect(verse.footnotes![0].marker, '¹');
      expect(verse.footnotes![0].content, 'Hebrew: bereshit');

      expect(verse.footnotes![1].id, 'f2');
      expect(verse.footnotes![1].marker, '²');
      expect(verse.footnotes![1].content, 'Hebrew: Elohim');

      // Two marker segments should exist
      final markerSegments =
          verse.segments!.where((s) => s.isFootnoteMarker).toList();
      expect(markerSegments, hasLength(2));
      expect(markerSegments[0].footnoteId, 'f1');
      expect(markerSegments[1].footnoteId, 'f2');
    });

    test('verse without footnotes has null footnotes field', () async {
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
      final verse = verses[0];

      expect(verse.hasFootnotes, isFalse);
      expect(verse.footnotes, isNull);
    });

    test('footnotes and Jesus words coexist in the same verse', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="3"/>
    <v id="16"/>For God so loved the world<f id="f1">See also Romans 5:8</f> that he gave his only Son, <wj>that whoever believes in him shall not perish.</wj><ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();
      final verse = verses[0];

      // Both features active
      expect(verse.hasJesusWords, isTrue);
      expect(verse.hasFootnotes, isTrue);
      expect(verse.footnotes, hasLength(1));
      expect(verse.footnotes![0].content, 'See also Romans 5:8');

      // Segments include a footnote marker and a Jesus segment
      final markerSegments =
          verse.segments!.where((s) => s.isFootnoteMarker).toList();
      final jesusSegments =
          verse.segments!.where((s) => s.isJesus).toList();
      expect(markerSegments, hasLength(1));
      expect(jesusSegments, hasLength(1));
    });

    test('footnote content is excluded from verse text', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>In the beginning<f id="f1">This is a long footnote with extra details</f> God created.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();
      final verse = verses[0];

      expect(verse.text, isNot(contains('This is a long footnote')));
      expect(verse.text, contains('In the beginning'));
      expect(verse.text, contains('God created'));
    });

    test('parseBooks also captures footnotes', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>In the beginning<f id="f1">Hebrew: bereshit</f> God created.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final books = await parser.parseBooks().toList();

      expect(books, hasLength(1));
      final verse = books[0].chapters[0].verses[0];

      expect(verse.hasFootnotes, isTrue);
      expect(verse.footnotes![0].content, 'Hebrew: bereshit');

      final markerSegments =
          verse.segments!.where((s) => s.isFootnoteMarker).toList();
      expect(markerSegments, hasLength(1));
    });

    test('footnote markers reset between verses', () async {
      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>Verse one<f id="f1">Note A</f> text.<ve/>
    <v id="2"/>Verse two<f id="f1">Note B</f> text.<ve/>
  </book>
</usfx>
''';

      final parser = UsfxParser(xml);
      final verses = await parser.parseVerses().toList();

      expect(verses, hasLength(2));

      // Both verses should have marker ¹ independently
      expect(verses[0].footnotes![0].marker, '¹');
      expect(verses[1].footnotes![0].marker, '¹');

      // Contents should be independent
      expect(verses[0].footnotes![0].content, 'Note A');
      expect(verses[1].footnotes![0].content, 'Note B');
    });
  });
}
