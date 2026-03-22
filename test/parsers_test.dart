import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/src/parsers/osis_parser.dart';
import 'package:bible_parser_flutter/src/parsers/usfx_parser.dart';
import 'package:bible_parser_flutter/src/parsers/zefania_parser.dart';
import 'package:bible_parser_flutter/src/rich_content.dart';

void main() {
  group('OSIS Parser Tests', () {
    final sampleOsisXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="KJV">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">In the beginning God created the heaven and the earth.</verse>
        <verse osisID="Gen.1.2">And the earth was without form, and void; and darkness was upon the face of the deep.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisXmlAlternativeVersion = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="KJV">
    <div type="book" osisID="Gen">
      <chapter osisRef="Gen.1" sID="Gen.1.seID.00001" n="1">
        <verse osisID="Gen.1.1" sID="Gen.1.1.seID.00002" n="1">In the beginning God created the heaven and the earth.<verse eID="Gen.1.1.seID.00002"/>
        <verse osisID="Gen.1.2" sID="Gen.1.2.seID.00003" n="2">And the earth was without form, and void; and darkness was upon the face of the deep.<verse eID="Gen.1.2.seID.00003"/>
      <chapter eID="Gen.1.seID.00001"/>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisRichXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <title type="main">The Gospel According to John</title>
      <chapter osisID="John.1">
        <title type="chapter">The Word</title>
        <verse osisID="John.1.1">
          <q who="Jesus">I am</q>
          <transChange type="added"> truly</transChange>
          <note n="a">Footnote <reference osisRef="Gen.1.1">Genesis 1:1</reference></note>
          <reference osisRef="Rev.1.8">Revelation 1:8</reference>
        </verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    test('OsisParser can parse sample XML', () async {
      final parser = OsisParser(sampleOsisXml);

      // Test format detection
      expect(parser.checkFormat(sampleOsisXml), isTrue);

      // Test book parsing
      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);
      expect(books.first.id, equals('gen'));
      expect(books.first.title, equals('Genesis'));

      // Test verse parsing
      final verses = await parser.parseVerses().toList();
      expect(verses.length, equals(2));
      expect(verses.first.num, equals(1));
      expect(verses.first.chapterNum, equals(1));
      expect(verses.first.bookId, equals('gen'));
      expect(verses.first.text, contains('In the beginning'));
    });

    test('OsisParser can parse sample XML with alternative version', () async {
      final parser = OsisParser(sampleOsisXmlAlternativeVersion);

      // Test format detection
      expect(parser.checkFormat(sampleOsisXmlAlternativeVersion), isTrue);

      // Test book parsing
      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);
      expect(books.first.id, equals('gen'));
      expect(books.first.title, equals('Genesis'));

      // Test verse parsing
      final verses = await parser.parseVerses().toList();
      expect(verses.length, equals(2));
      expect(verses.first.num, equals(1));
      expect(verses.first.chapterNum, equals(1));
      expect(verses.first.bookId, equals('gen'));
      expect(verses.first.text, contains('In the beginning'));
    });

    test('OsisParser preserves rich structured metadata', () async {
      final parser = OsisParser(sampleOsisRichXml);

      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);

      final john = books.first;
      expect(john.tocLabels, isNotEmpty);
      expect(john.introductionBlocks.any((b) => b.text.contains('Gospel')),
          isTrue);
      expect(john.chapters.first.blocks.any((b) => b.text.contains('The Word')),
          isTrue);

      final verse = john.chapters.first.verses.first;
      expect(verse.footnotes, isNotEmpty);
      expect(verse.footnotes.first.text, contains('Footnote'));
      expect(verse.footnotes.first.references, isNotEmpty);
      expect(verse.crossReferences, isNotEmpty);
      expect(verse.crossReferences.first.target, equals('Rev.1.8'));
      expect(
        verse.spans.any((span) => span.kind == VerseSpanKind.wordsOfJesus),
        isTrue,
      );
      expect(
        verse.spans
            .any((span) => span.kind == VerseSpanKind.translatorAddition),
        isTrue,
      );
    });
  });

  group('USFX Parser Tests', () {
    final sampleUsfxXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1">
      <v id="1">In the beginning God created the heaven and the earth.</v>
      <v id="2">And the earth was without form, and void; and darkness was upon the face of the deep.</v>
    </c>
  </book>
</usfx>
''';

    final sampleUsfxXmlAlternativeVersion = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
      <v id="1">In the beginning God created the heaven and the earth.<ve/>
      <v id="2">And the earth was without form, and void; and darkness was upon the face of the deep.<ve/>
  </book>
</usfx>
''';

    final sampleUsfxRichXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="FRT">
    <h>Preface</h>
    <toc level="1">Preface</toc>
    <p>This is the Bible preface.</p>
  </book>
  <book id="GEN">
    <h>Genesis</h>
    <toc level="1">The First Book of Moses, Called Genesis</toc>
    <toc level="2">Genesis</toc>
    <p>This is the introduction to Genesis.</p>
    <c id="1">
      <v id="1">In the beginning<f caller="+"><fr>1.1</fr><ft>Footnote text</ft></f><x caller="+"><ref tgt="JHN.1.1">John 1:1</ref></x>.</v>
    </c>
  </book>
</usfx>
''';
    final sampleUsfxSpanXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="JHN">
    <c id="1">
      <v id="1"><wj><w s="G1473">I</w> am</wj> the <add>good</add> shepherd.<q level="2">My sheep hear my voice.</q></v>
    </c>
  </book>
</usfx>
''';
    final sampleUsfxParagraphXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1">
      <p sfm="p"/>
      <v id="1">In the beginning God created the heaven and the earth.</v>
      <v id="2">And the earth was without form, and void.</v>
      <p sfm="m"/>
      <v id="3">And God said, Let there be light.</v>
    </c>
  </book>
</usfx>
''';

    test('UsfxParser can parse sample XML', () async {
      final parser = UsfxParser(sampleUsfxXml);

      // Test format detection
      expect(parser.checkFormat(sampleUsfxXml), isTrue);

      // Test book parsing
      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);
      expect(books.first.id, equals('gen'));

      // Test verse parsing
      final verses = await parser.parseVerses().toList();
      expect(verses.length, equals(2));
      expect(verses.first.num, equals(1));
      expect(verses.first.chapterNum, equals(1));
      expect(verses.first.bookId, equals('gen'));
      expect(verses.first.text, contains('In the beginning'));
    });

    test('UsfxParser can parse sample XML with alternative version', () async {
      final parser = UsfxParser(sampleUsfxXmlAlternativeVersion);

      // Test format detection
      expect(parser.checkFormat(sampleUsfxXmlAlternativeVersion), isTrue);

      // Test book parsing
      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);
      expect(books.first.id, equals('gen'));

      // Test verse parsing
      final verses = await parser.parseVerses().toList();
      expect(verses.length, equals(2));
      expect(verses.first.num, equals(1));
      expect(verses.first.chapterNum, equals(1));
      expect(verses.first.bookId, equals('gen'));
      expect(verses.first.text, contains('In the beginning'));
    });

    test('UsfxParser preserves rich structured metadata', () async {
      final parser = UsfxParser(sampleUsfxRichXml);

      final books = await parser.parseBooks().toList();
      expect(books.length, equals(2));

      final preface = books.first;
      expect(preface.id, equals('frt'));
      expect(preface.introductionBlocks, isNotEmpty);
      expect(preface.introductionBlocks.first.text, contains('Preface'));
      expect(preface.tocLabels, isNotEmpty);

      final genesis = books.last;
      expect(genesis.tocLabels.length, equals(2));
      expect(genesis.introductionBlocks.any((b) => b.text.contains('Genesis')),
          isTrue);
      expect(
        genesis.introductionBlocks
            .any((b) => b.text.contains('introduction to Genesis')),
        isTrue,
      );

      final verse = genesis.chapters.first.verses.first;
      expect(verse.notes, contains('Footnote text'));
      expect(verse.footnotes, isNotEmpty);
      expect(verse.footnotes.first.label, equals('1.1'));
      expect(verse.references, contains('John 1:1'));
      expect(verse.crossReferences, isNotEmpty);
      expect(verse.crossReferences.first.target, equals('JHN.1.1'));
      expect(verse.spans, isNotEmpty);
    });

    test('UsfxParser preserves rich span kinds', () async {
      final parser = UsfxParser(sampleUsfxSpanXml);

      final verse = (await parser.parseVerses().toList()).first;

      expect(
        verse.spans.any((span) => span.kind == VerseSpanKind.wordsOfJesus),
        isTrue,
      );
      expect(
        verse.spans.any((span) => span.metadata['strongs'] == 'G1473'),
        isTrue,
      );
      expect(
        verse.spans
            .any((span) => span.kind == VerseSpanKind.translatorAddition),
        isTrue,
      );
      expect(
        verse.spans.any((span) => span.kind == VerseSpanKind.poetry),
        isTrue,
      );
    });

    test('UsfxParser preserves chapter paragraph boundaries', () async {
      final parser = UsfxParser(sampleUsfxParagraphXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      final paragraphBlocks = chapter.blocks
          .where((block) => block.kind == DocumentBlockKind.paragraph)
          .toList();

      expect(paragraphBlocks, hasLength(2));
      expect(paragraphBlocks.first.metadata['beforeVerse'], equals('1'));
      expect(paragraphBlocks.first.metadata['style'], equals('p'));
      expect(paragraphBlocks.last.metadata['beforeVerse'], equals('3'));
      expect(paragraphBlocks.last.metadata['style'], equals('m'));
    });
  });

  group('ZXBML Parser Tests', () {
    final sampleZefaniaXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<XMLBIBLE>
  <BIBLEBOOK bsname="GEN">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">In the beginning God created the heaven and the earth.</VERS>
      <VERS vnumber="2">And the earth was without form, and void; and darkness was upon the face of the deep.</VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>
''';
    final sampleZefaniaRichXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<XMLBIBLE>
  <BIBLEBOOK bnumber="43" bname="John" bsname="JHN">
    <PROLOG>This is the introduction to John.</PROLOG>
    <CHAPTER cnumber="1">
      <CAPTION>The Word Became Flesh</CAPTION>
      <VERS vnumber="1">
        <STYLE css="color: red">I am</STYLE>
        the
        <STYLE css="font-style: italic" gr="G2570">good</STYLE>
        shepherd.
        <NOTE type="study">Footnote text</NOTE>
        <XREF fscope="JHN.10.11">John 10:11</XREF>
      </VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>
''';

    test('ZefaniaParser can parse sample XML', () async {
      final parser = ZefaniaParser(sampleZefaniaXml);

      // Test format detection
      expect(parser.checkFormat(sampleZefaniaXml), isTrue);

      // Test book parsing
      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);
      expect(books.first.id.toLowerCase(), equals('gen'));

      // Test verse parsing
      final verses = await parser.parseVerses().toList();
      expect(verses.length, equals(2));
      expect(verses.first.num, equals(1));
      expect(verses.first.chapterNum, equals(1));
      expect(verses.first.bookId.toLowerCase(), equals('gen'));
      expect(verses.first.text, contains('In the beginning'));
    });

    test('ZefaniaParser preserves rich structured metadata', () async {
      final parser = ZefaniaParser(sampleZefaniaRichXml);

      final books = await parser.parseBooks().toList();
      expect(books, isNotEmpty);

      final john = books.first;
      expect(john.tocLabels, isNotEmpty);
      expect(
        john.introductionBlocks
            .any((block) => block.text.contains('introduction')),
        isTrue,
      );
      expect(
        john.chapters.first.blocks
            .any((block) => block.text.contains('The Word Became Flesh')),
        isTrue,
      );

      final verse = john.chapters.first.verses.first;
      expect(verse.footnotes, isNotEmpty);
      expect(verse.footnotes.first.text, contains('Footnote text'));
      expect(verse.crossReferences, isNotEmpty);
      expect(verse.crossReferences.first.target, equals('JHN.10.11'));
      expect(
        verse.spans.any((span) => span.kind == VerseSpanKind.wordsOfJesus),
        isTrue,
      );
      expect(
        verse.spans
            .any((span) => span.kind == VerseSpanKind.translatorAddition),
        isTrue,
      );
      expect(
        verse.spans.any((span) => span.metadata['gr'] == 'G2570'),
        isTrue,
      );
    });
  });
}
