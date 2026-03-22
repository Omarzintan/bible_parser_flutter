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
    final sampleOsisParagraphXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <chapter osisID="John.1">
        <p type="x-p"/>
        <verse osisID="John.1.1">In the beginning was the Word.</verse>
        <verse osisID="John.1.2">He was in the beginning with God.</verse>
        <p subType="x-indented"/>
        <verse osisID="John.1.3">All things were made through him.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisPoetryXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <chapter osisID="John.1">
        <p type="poetry"/>
        <verse osisID="John.1.1">
          <q level="2">First line</q>
          <q level="2">Second line</q>
        </verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisIntroBlocksXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <head type="major">Book Head</head>
      <p type="preface">This is the book preface.</p>
      <chapter osisID="John.1">
        <head subType="x-section">Section Head</head>
        <verse osisID="John.1.1">In the beginning was the Word.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisLineGroupXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <chapter osisID="John.1">
        <lg type="poetry">
          <l level="1">First block line</l>
          <l level="2">Second block line</l>
        </lg>
        <verse osisID="John.1.1">
          <l level="1">First verse line</l>
          <l level="2">Second verse line</l>
        </verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisSpeakerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <chapter osisID="John.1">
        <speaker who="Jesus">Jesus</speaker>
        <verse osisID="John.1.1">
          <q who="Jesus">I am the light of the world.</q>
        </verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisNestedSectionXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <chapter osisID="John.1">
        <div type="section" subType="x-test-section" osisID="John.1.section.1">
          <title type="section">Section Title</title>
          <p type="x-p">Section intro paragraph.</p>
          <verse osisID="John.1.1">In the beginning was the Word.</verse>
        </div>
        <verse osisID="John.1.2">He was in the beginning with God.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisListXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <list type="outline" subType="x-study">
        <item type="label" level="1">Intro list item</item>
      </list>
      <chapter osisID="John.1">
        <div type="section" osisID="John.1.section.1">
          <list type="poetry">
            <item level="2">Indented chapter item</item>
          </list>
        </div>
        <verse osisID="John.1.1">In the beginning was the Word.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';
    final sampleOsisLineBreakXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="TEST">
    <div type="book" osisID="John">
      <chapter osisID="John.1">
        <verse osisID="John.1.1">In the beginning was the Word.</verse>
        <lb />
        <verse osisID="John.1.2">He was in the beginning with God.</verse>
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
      expect(verse.footnotes.first.marker, equals('a'));
      expect(verse.footnotes.first.text, contains('Footnote'));
      expect(verse.footnotes.first.references, isNotEmpty);
      expect(verse.crossReferences, isNotEmpty);
      expect(verse.crossReferences.first.target, equals('Rev.1.8'));
      expect(verse.crossReferences.first.marker, equals('b'));
      expect(
        verse.spans.any((span) => span.metadata['footnoteMarkers'] == 'a'),
        isTrue,
      );
      expect(
        verse.spans.any((span) => span.metadata['referenceMarkers'] == 'b'),
        isTrue,
      );
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

    test('OsisParser preserves chapter paragraph boundaries', () async {
      final parser = OsisParser(sampleOsisParagraphXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      final paragraphBlocks = chapter.blocks
          .where((block) => block.kind == DocumentBlockKind.paragraph)
          .toList();

      expect(paragraphBlocks, hasLength(2));
      expect(paragraphBlocks.first.metadata['beforeVerse'], equals('1'));
      expect(paragraphBlocks.first.metadata['type'], equals('x-p'));
      expect(paragraphBlocks.last.metadata['beforeVerse'], equals('3'));
      expect(paragraphBlocks.last.metadata['subType'], equals('x-indented'));
    });

    test('OsisParser preserves poetry markers and line starts', () async {
      final parser = OsisParser(sampleOsisPoetryXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      expect(chapter.blocks.first.kind, equals(DocumentBlockKind.poetry));

      final verse = chapter.verses.first;
      final poetrySpans = verse.spans
          .where((span) => span.kind == VerseSpanKind.poetry)
          .toList();

      expect(poetrySpans, hasLength(2));
      expect(poetrySpans.first.metadata['lineStart'], equals('true'));
      expect(poetrySpans.first.metadata['quoteLevel'], equals('2'));
      expect(poetrySpans.last.metadata['lineStart'], equals('true'));
    });

    test('OsisParser preserves intro paragraphs and head blocks', () async {
      final parser = OsisParser(sampleOsisIntroBlocksXml);

      final john = (await parser.parseBooks().toList()).first;
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('Book Head') &&
              block.metadata['sourceTag'] == 'head' &&
              block.metadata['type'] == 'major',
        ),
        isTrue,
      );
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.preface &&
              block.text.contains('book preface') &&
              block.metadata['sourceTag'] == 'p' &&
              block.metadata['type'] == 'preface',
        ),
        isTrue,
      );
      expect(
        john.chapters.first.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('Section Head') &&
              block.metadata['sourceTag'] == 'head' &&
              block.metadata['subType'] == 'x-section',
        ),
        isTrue,
      );
    });

    test('OsisParser preserves line-group poetry structure', () async {
      final parser = OsisParser(sampleOsisLineGroupXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      expect(
        chapter.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.poetry &&
              block.metadata['sourceTag'] == 'lg' &&
              block.metadata['beforeVerse'] == '1' &&
              block.text.contains('First block line') &&
              block.text.contains('Second block line'),
        ),
        isTrue,
      );

      final verse = chapter.verses.first;
      final poetrySpans = verse.spans
          .where((span) => span.kind == VerseSpanKind.poetry)
          .toList();

      expect(poetrySpans, hasLength(2));
      expect(poetrySpans.first.metadata['lineStart'], equals('true'));
      expect(poetrySpans.first.metadata['quoteLevel'], equals('1'));
      expect(poetrySpans.last.metadata['lineStart'], equals('true'));
      expect(poetrySpans.last.metadata['quoteLevel'], equals('2'));
    });

    test('OsisParser preserves speaker blocks', () async {
      final parser = OsisParser(sampleOsisSpeakerXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      expect(
        chapter.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text == 'Jesus' &&
              block.metadata['sourceTag'] == 'speaker' &&
              block.metadata['who'] == 'Jesus',
        ),
        isTrue,
      );

      final verse = chapter.verses.first;
      expect(
        verse.spans.any((span) => span.kind == VerseSpanKind.wordsOfJesus),
        isTrue,
      );
    });

    test('OsisParser keeps nested section divs from closing the book',
        () async {
      final parser = OsisParser(sampleOsisNestedSectionXml);

      final books = await parser.parseBooks().toList();
      expect(books, hasLength(1));

      final chapter = books.first.chapters.first;
      expect(chapter.verses, hasLength(2));
      expect(chapter.verses.last.num, equals(2));

      final sectionTitle = chapter.blocks.firstWhere(
        (block) => block.text.contains('Section Title'),
      );
      expect(sectionTitle.metadata['sectionType'], equals('section'));
      expect(
        sectionTitle.metadata['sectionSubType'],
        equals('x-test-section'),
      );
      expect(
        sectionTitle.metadata['sectionOsisId'],
        equals('John.1.section.1'),
      );

      final sectionParagraph = chapter.blocks.firstWhere(
        (block) => block.text.contains('Section intro paragraph.'),
      );
      expect(sectionParagraph.metadata['sectionType'], equals('section'));
      expect(sectionParagraph.metadata['sourceTag'], equals('p'));
    });

    test('OsisParser preserves non-verse list items as structured blocks',
        () async {
      final parser = OsisParser(sampleOsisListXml);

      final john = (await parser.parseBooks().toList()).first;
      final introItem = john.introductionBlocks.firstWhere(
        (block) => block.text.contains('Intro list item'),
      );
      expect(introItem.kind, isNotNull);
      expect(introItem.metadata['sourceTag'], equals('item'));
      expect(introItem.metadata['listType'], equals('outline'));
      expect(introItem.metadata['listSubType'], equals('x-study'));
      expect(introItem.metadata['itemType'], equals('label'));
      expect(introItem.metadata['itemLevel'], equals('1'));

      final chapterItem = john.chapters.first.blocks.firstWhere(
        (block) => block.text.contains('Indented chapter item'),
      );
      expect(chapterItem.kind, equals(DocumentBlockKind.poetry));
      expect(chapterItem.metadata['sourceTag'], equals('item'));
      expect(chapterItem.metadata['listType'], equals('poetry'));
      expect(chapterItem.metadata['itemLevel'], equals('2'));
      expect(chapterItem.metadata['sectionType'], equals('section'));
    });

    test('OsisParser preserves line-break markers as layout blocks', () async {
      final parser = OsisParser(sampleOsisLineBreakXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      expect(
        chapter.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.paragraph &&
              block.metadata['sourceTag'] == 'lb' &&
              block.metadata['style'] == 'lb' &&
              block.metadata['beforeVerse'] == '2',
        ),
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
    final sampleUsfxPoetryXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1">
      <p sfm="q1"/>
      <v id="1"><q level="2">First line</q><q level="2">Second line</q></v>
    </c>
  </book>
</usfx>
''';
    final sampleUsfxBreakXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1">
      <b/>
      <v id="1">In the beginning God created the heaven and the earth.</v>
    </c>
  </book>
</usfx>
''';
    final sampleUsfxSectionBlocksXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="FRT">
    <imt1>General Preface</imt1>
    <ip>This is preface paragraph text.</ip>
    <ili1>Preface list item</ili1>
  </book>
  <book id="JHN">
    <mt1>The Gospel According to John</mt1>
    <is1>Prologue</is1>
    <li1>Intro outline item</li1>
    <cl>Chapter One</cl>
    <c id="1">
      <s1>The Eternal Word</s1>
      <li2>Indented section item</li2>
      <d>A Psalm-style line</d>
      <v id="1">In the beginning was the Word.</v>
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
      expect(verse.footnotes.first.marker, equals('a'));
      expect(verse.footnotes.first.label, equals('1.1'));
      expect(verse.references, contains('John 1:1'));
      expect(verse.crossReferences, isNotEmpty);
      expect(verse.crossReferences.first.target, equals('JHN.1.1'));
      expect(verse.crossReferences.first.marker, equals('b'));
      expect(
        verse.spans.any((span) => span.metadata['footnoteMarkers'] == 'a'),
        isTrue,
      );
      expect(
        verse.spans.any((span) => span.metadata['referenceMarkers'] == 'b'),
        isTrue,
      );
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

    test('UsfxParser preserves poetry markers and line starts', () async {
      final parser = UsfxParser(sampleUsfxPoetryXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      expect(chapter.blocks.first.kind, equals(DocumentBlockKind.poetry));

      final verse = chapter.verses.first;
      final poetrySpans = verse.spans
          .where((span) => span.kind == VerseSpanKind.poetry)
          .toList();

      expect(poetrySpans, hasLength(2));
      expect(poetrySpans.first.metadata['lineStart'], equals('true'));
      expect(poetrySpans.first.metadata['quoteLevel'], equals('2'));
      expect(poetrySpans.last.metadata['lineStart'], equals('true'));
    });

    test('UsfxParser preserves break markers as document blocks', () async {
      final parser = UsfxParser(sampleUsfxBreakXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      expect(
        chapter.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.paragraph &&
              block.metadata['sourceTag'] == 'b' &&
              block.metadata['style'] == 'b' &&
              block.metadata['beforeVerse'] == '1',
        ),
        isTrue,
      );
    });

    test('UsfxParser preserves additional front matter and section tags',
        () async {
      final parser = UsfxParser(sampleUsfxSectionBlocksXml);

      final books = await parser.parseBooks().toList();
      expect(books, hasLength(2));

      final preface = books.first;
      expect(
        preface.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.preface &&
              block.text.contains('General Preface') &&
              block.metadata['sourceTag'] == 'imt1',
        ),
        isTrue,
      );
      expect(
        preface.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.preface &&
              block.text.contains('preface paragraph text') &&
              block.metadata['sourceTag'] == 'ip',
        ),
        isTrue,
      );
      expect(
        preface.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.paragraph &&
              block.text.contains('Preface list item') &&
              block.metadata['sourceTag'] == 'ili1' &&
              block.level == 1,
        ),
        isTrue,
      );

      final john = books.last;
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('Gospel According to John') &&
              block.metadata['sourceTag'] == 'mt1' &&
              block.level == 1,
        ),
        isTrue,
      );
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('Prologue') &&
              block.metadata['sourceTag'] == 'is1',
        ),
        isTrue,
      );
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.paragraph &&
              block.text.contains('Intro outline item') &&
              block.metadata['sourceTag'] == 'li1' &&
              block.level == 1,
        ),
        isTrue,
      );
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('Chapter One') &&
              block.metadata['sourceTag'] == 'cl',
        ),
        isTrue,
      );
      expect(
        john.chapters.first.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('The Eternal Word') &&
              block.metadata['sourceTag'] == 's1' &&
              block.level == 1,
        ),
        isTrue,
      );
      expect(
        john.chapters.first.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.paragraph &&
              block.text.contains('Indented section item') &&
              block.metadata['sourceTag'] == 'li2' &&
              block.level == 2,
        ),
        isTrue,
      );
      expect(
        john.chapters.first.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.poetry &&
              block.text.contains('A Psalm-style line') &&
              block.metadata['sourceTag'] == 'd',
        ),
        isTrue,
      );
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
    final sampleZefaniaParagraphXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<XMLBIBLE>
  <BIBLEBOOK bnumber="43" bname="John" bsname="JHN">
    <CHAPTER cnumber="1">
      <BR art="p"/>
      <VERS vnumber="1">In the beginning was the Word.</VERS>
      <VERS vnumber="2">He was in the beginning with God.</VERS>
      <BR art="q1"/>
      <VERS vnumber="3">All things were made through him.</VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>
''';
    final sampleZefaniaPoetryXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<XMLBIBLE>
  <BIBLEBOOK bnumber="43" bname="John" bsname="JHN">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">
        <STYLE css="poetry">First line</STYLE>
        <STYLE css="poetry">Second line</STYLE>
      </VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>
''';
    final sampleZefaniaBlockMetadataXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<XMLBIBLE>
  <BIBLEBOOK bnumber="43" bname="John" bsname="JHN">
    <PROLOG type="preface">This is the preface to John.</PROLOG>
    <CHAPTER cnumber="1">
      <CAPTION vref="1" type="outline">The Witness</CAPTION>
      <VERS vnumber="1">In the beginning was the Word.</VERS>
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
      expect(verse.footnotes.first.marker, equals('study'));
      expect(verse.footnotes.first.text, contains('Footnote text'));
      expect(verse.crossReferences, isNotEmpty);
      expect(verse.crossReferences.first.target, equals('JHN.10.11'));
      expect(verse.crossReferences.first.marker, equals('a'));
      expect(
        verse.spans.any(
          (span) => span.metadata['footnoteMarkers'] == 'study',
        ),
        isTrue,
      );
      expect(
        verse.spans.any((span) => span.metadata['referenceMarkers'] == 'a'),
        isTrue,
      );
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

    test('ZefaniaParser preserves chapter paragraph boundaries', () async {
      final parser = ZefaniaParser(sampleZefaniaParagraphXml);

      final chapter = (await parser.parseBooks().toList()).first.chapters.first;
      final blocks = chapter.blocks;
      expect(blocks, hasLength(2));
      expect(blocks.first.kind, equals(DocumentBlockKind.paragraph));
      expect(blocks.first.metadata['sourceTag'], equals('BR'));
      expect(blocks.first.metadata['beforeVerse'], equals('1'));
      expect(blocks.first.metadata['art'], equals('p'));
      expect(blocks.last.kind, equals(DocumentBlockKind.poetry));
      expect(blocks.last.metadata['sourceTag'], equals('BR'));
      expect(blocks.last.metadata['beforeVerse'], equals('3'));
      expect(blocks.last.metadata['art'], equals('q1'));
    });

    test('ZefaniaParser preserves poetry line starts', () async {
      final parser = ZefaniaParser(sampleZefaniaPoetryXml);

      final verse = (await parser.parseBooks().toList())
          .first
          .chapters
          .first
          .verses
          .first;
      final poetrySpans = verse.spans
          .where((span) => span.kind == VerseSpanKind.poetry)
          .toList();

      expect(poetrySpans, hasLength(2));
      expect(poetrySpans.first.metadata['lineStart'], equals('true'));
      expect(poetrySpans.last.metadata['lineStart'], equals('true'));
    });

    test('ZefaniaParser preserves source metadata for intro blocks', () async {
      final parser = ZefaniaParser(sampleZefaniaBlockMetadataXml);

      final john = (await parser.parseBooks().toList()).first;
      expect(
        john.introductionBlocks.any(
          (block) =>
              block.kind == DocumentBlockKind.introduction &&
              block.text.contains('preface to John') &&
              block.metadata['sourceTag'] == 'PROLOG' &&
              block.metadata['type'] == 'preface',
        ),
        isTrue,
      );
      expect(
        john.chapters.first.blocks.any(
          (block) =>
              block.kind == DocumentBlockKind.heading &&
              block.text.contains('The Witness') &&
              block.metadata['sourceTag'] == 'CAPTION' &&
              block.metadata['vref'] == '1' &&
              block.metadata['type'] == 'outline',
        ),
        isTrue,
      );
    });
  });
}
