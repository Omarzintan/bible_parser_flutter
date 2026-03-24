// Fixture-based regression tests for all three Bible parsers.
//
// Each test uses a minimal but realistic XML snippet so that parser changes
// can be verified against real format semantics rather than mocked data.
// One test per format per feature area — just enough to catch regressions.
//
// Coverage per format:
//   - basic verse text extraction
//   - footnote structure (Footnote object with text, label, marker)
//   - cross-reference structure (CrossReference with label and target)
//   - red-letter / words-of-Jesus spans (VerseSpanKind.wordsOfJesus)
//   - section heading blocks (DocumentBlockKind.heading in chapter.blocks)
//
// When a parser feature is changed, run these tests first.  If a test
// breaks, fix the parser, then update the test to reflect the new (correct)
// behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parses [xml] with the given [format] and returns the first Book, or null.
Future<Book?> _parseFirstBook(String xml, String format) async {
  final parser = BibleParser.fromString(xml, format: format);
  final books = await parser.books.toList();
  return books.isEmpty ? null : books.first;
}

/// Returns the first Verse from [book], or null.
Verse? _firstVerse(Book book) {
  if (book.chapters.isEmpty) return null;
  final chapter = book.chapters.first;
  if (chapter.verses.isEmpty) return null;
  return chapter.verses.first;
}

// ---------------------------------------------------------------------------
// USFX fixtures
// ---------------------------------------------------------------------------

const _usfxBasic = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">In the beginning God created the heaven and the earth.</v>
    </c>
  </book>
</usfx>''';

/// USFX footnote with <fr> origin reference and <ft> body text.
const _usfxFootnote = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">In the beginning<f caller="a"><fr>1:1 </fr><ft>A creation footnote.</ft></f> God created.</v>
    </c>
  </book>
</usfx>''';

/// USFX footnote with both <ft> body text and <fq> quoted text.
const _usfxFootnoteWithQuote = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">God said<f caller="a"><fr>1:3 </fr><ft>Or </ft><fq>Let there be light</fq><ft>, meaning...</ft></f> the word.</v>
    </c>
  </book>
</usfx>''';

/// USFX cross-reference with <ref tgt="..."> target.
const _usfxCrossRef = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">God created the heaven.<x caller="b"><ref tgt="GEN.1.1">Gen. 1:1</ref></x></v>
    </c>
  </book>
</usfx>''';

/// USFX cross-reference with <xo> origin-verse tag.
const _usfxCrossRefWithOrigin = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">In the beginning.<x caller="b"><xo>1:1 </xo><ref tgt="GEN.1.2">Gen. 1:2</ref></x></v>
    </c>
  </book>
</usfx>''';

/// USFX red-letter text via <wj>.
const _usfxRedLetter = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="MAT">
    <c id="5">
      <v id="3"><wj>Blessed are the poor in spirit: for theirs is the kingdom of heaven.</wj></v>
    </c>
  </book>
</usfx>''';

/// USFX stanza break via <b> between verse groups.
const _usfxStanzaBreak = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="PSA">
    <c id="1">
      <v id="1">Blessed is the man.</v>
      <b />
      <v id="2">But his delight is in the law.</v>
    </c>
  </book>
</usfx>''';

/// USFX section heading via <s1> before the first verse.
const _usfxHeading = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <s1>The Creation</s1>
      <v id="1">In the beginning God created the heaven and the earth.</v>
    </c>
  </book>
</usfx>''';

/// USFX divine name via <nd>.
const _usfxDivineName = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">I am <nd>LORD</nd> your God.</v>
    </c>
  </book>
</usfx>''';

/// USFX translator addition via <add>.
const _usfxTranslatorAdd = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN">
    <c id="1">
      <v id="1">And the earth was <add>without form</add>, and void.</v>
    </c>
  </book>
</usfx>''';

// ---------------------------------------------------------------------------
// OSIS fixtures
// ---------------------------------------------------------------------------

const _osisBasic = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">In the beginning God created the heaven and the earth.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS footnote via <note n="a">.
const _osisFootnote = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">In the beginning<note n="a">A note about this verse.</note> God created.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS standalone cross-reference via <reference osisRef="...">.
const _osisCrossRef = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">God created.<reference osisRef="Gen.1.1">Gen 1:1</reference></verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS cross-reference note with origin-verse tag.
const _osisCrossRefWithOrigin = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">In the beginning.<note type="crossReference" n="a"><reference type="source">1:1</reference><reference osisRef="Gen.1.2">Gen 1:2</reference></note></verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS divine name via <divineName>.
const _osisDivineName = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">I am <divineName>LORD</divineName> your God.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS bold text via <hi type="bold">.
const _osisHiBold = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">Thus says <hi type="bold">the LORD</hi>.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS italic text via <hi type="italic">.
const _osisHiItalic = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">The book of <hi type="italic">Genesis</hi>.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS red-letter text via <q who="Jesus">.
const _osisRedLetter = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Matt">
      <chapter osisID="Matt.5">
        <verse osisID="Matt.5.3"><q who="Jesus">Blessed are the poor in spirit.</q></verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS chapter title via <title> before the verse.
const _osisTitle = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <title>The Creation</title>
        <verse osisID="Gen.1.1">In the beginning God created the heaven and the earth.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS stanza break via empty <l /> inside <lg>.
const _osisStanzaBreak = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Ps">
      <chapter osisID="Ps.1">
        <lg>
          <l>Blessed is the man.</l>
          <l />
          <l>But his delight is in the law.</l>
        </lg>
        <verse osisID="Ps.1.1">Blessed is the man.</verse>
        <verse osisID="Ps.1.2">But his delight is in the law.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS non-Jesus quote speaker attribution via <q who="Yahweh">.
const _osisQuoteWho = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Isa">
      <chapter osisID="Isa.1">
        <verse osisID="Isa.1.1"><q who="Yahweh">I have nourished and brought up children.</q></verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// OSIS table rows via <table><row><cell>.
const _osisTable = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <table type="x-study">
          <row type="label">
            <cell role="label">Day</cell>
            <cell role="value">One</cell>
          </row>
          <row>
            <cell role="label">Light</cell>
            <cell role="value">Created</cell>
          </row>
        </table>
        <verse osisID="Gen.1.1">In the beginning God created.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

/// USFX non-Jesus quote speaker attribution via <q who="...">.
const _usfxQuoteWho = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="ISA"><c id="1">
    <v id="1"><q who="Yahweh" level="1">I have nourished and brought up children.</q></v>
  </c></book>
</usfx>''';

/// USFX inline emphasis via <em>.
const _usfxEmphasis = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN"><c id="1">
    <v id="1">This is <em>very</em> important.</v>
  </c></book>
</usfx>''';

/// USFX bold text via <bd>.
const _usfxBold = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN"><c id="1">
    <v id="1">Thus says <bd>the LORD</bd>.</v>
  </c></book>
</usfx>''';

/// USFX italic text via <it>.
const _usfxItalic = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN"><c id="1">
    <v id="1">The book of <it>Genesis</it>.</v>
  </c></book>
</usfx>''';

/// USFX proper name via <pn>.
const _usfxProperName = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN"><c id="1">
    <v id="1">God said to <pn>Abram</pn>, go.</v>
  </c></book>
</usfx>''';

/// USFX Selah music cue via <qs>.
const _usfxSelah = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="PSA"><c id="3">
    <v id="2">Many are rising against me. <qs>Selah</qs></v>
  </c></book>
</usfx>''';

/// USFX acrostic heading via <qa>.
const _usfxAcrosticHeading = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="PSA"><c id="119">
    <v id="1"><qa>א</qa> Blessed are the undefiled in the way.</v>
  </c></book>
</usfx>''';

/// USFX word metadata with Strong's, lemma, and morphology.
const _usfxWordMetadata = '''<?xml version="1.0" encoding="utf-8"?>
<usfx xmlns="http://www.bibletechnologies.net/2003/USFX/namespace">
  <book id="GEN"><c id="1">
    <v id="1"><w s="H7225" l="reshith" m="HNcfsa">Beginning</w> God created.</v>
  </c></book>
</usfx>''';

/// OSIS word metadata with lemma and morph.
const _osisWordMetadata = '''<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="test">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1"><w lemma="strong:H7225" morph="HNcfsa">Beginning</w> God created.</verse>
      </chapter>
    </div>
  </osisText>
</osis>''';

// ---------------------------------------------------------------------------
// Zefania fixtures
// ---------------------------------------------------------------------------

const _zefaniaBasic = '''<?xml version="1.0" encoding="utf-8"?>
<XMLBIBLE xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    biblename="TestBible" type="x-bible">
  <BIBLEBOOK bnumber="1" bname="Genesis" bsname="Gen">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">In the beginning God created the heaven and the earth.</VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>''';

/// Zefania footnote via <NOTE>.
const _zefaniaFootnote = '''<?xml version="1.0" encoding="utf-8"?>
<XMLBIBLE xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    biblename="TestBible" type="x-bible">
  <BIBLEBOOK bnumber="1" bname="Genesis" bsname="Gen">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">In the beginning<NOTE>A footnote about creation.</NOTE> God created.</VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>''';

/// Zefania cross-reference via <XREF fscope="...">.
const _zefaniaCrossRef = '''<?xml version="1.0" encoding="utf-8"?>
<XMLBIBLE xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    biblename="TestBible" type="x-bible">
  <BIBLEBOOK bnumber="1" bname="Genesis" bsname="Gen">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">God created the heaven.<XREF fscope="Gen.1.1">Gen 1:1</XREF></VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>''';

/// Zefania red-letter text via <STYLE css="wj">.
/// Note: the Zefania parser reads css/id/style attributes (not type), so the
/// fixture must use one of those attribute names for style detection to fire.
const _zefaniaRedLetter = '''<?xml version="1.0" encoding="utf-8"?>
<XMLBIBLE xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    biblename="TestBible" type="x-bible">
  <BIBLEBOOK bnumber="40" bname="Matthew" bsname="Matt">
    <CHAPTER cnumber="5">
      <VERS vnumber="3"><STYLE css="wj">Blessed are the poor in spirit.</STYLE></VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>''';

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // -------------------------------------------------------------------------
  // USFX
  // -------------------------------------------------------------------------

  group('USFX parser', () {
    test('parses basic verse text', () async {
      final book = await _parseFirstBook(_usfxBasic, 'USFX');

      expect(book, isNotNull);
      expect(book!.id, equals('gen'));
      expect(book.chapters, hasLength(1));

      final verse = _firstVerse(book);
      expect(verse, isNotNull);
      expect(verse!.num, equals(1));
      expect(verse.chapterNum, equals(1));
      expect(verse.text, contains('beginning'));
    });

    test('preserves footnote with origin label and body text', () async {
      final book = await _parseFirstBook(_usfxFootnote, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.footnotes, hasLength(1));

      final fn = verse.footnotes.first;
      // <ft> body text must survive in both the structured field and text fallback.
      expect(fn.bodyText, isNotNull);
      expect(fn.bodyText, contains('creation footnote'));
      expect(fn.text, contains('creation footnote'));
      // <fr> origin reference goes to the label field.
      expect(fn.label, isNotNull);
      expect(fn.label!.trim(), equals('1:1'));
      // Caller attribute drives the marker.
      expect(fn.marker, equals('a'));

      // Legacy plain-text list is also populated for backwards compatibility.
      expect(verse.notes, hasLength(1));
    });

    test('preserves quoted text from <fq> as a separate field', () async {
      final book = await _parseFirstBook(_usfxFootnoteWithQuote, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.footnotes, hasLength(1));

      final fn = verse.footnotes.first;
      // <fq> quoted text must land in quotedText, not be lost.
      expect(fn.quotedText, isNotNull);
      expect(fn.quotedText, contains('Let there be light'));
      // Combined text fallback must still contain all non-fr content.
      expect(fn.text, contains('Let there be light'));
    });

    test('preserves cross-reference with target', () async {
      final book = await _parseFirstBook(_usfxCrossRef, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.crossReferences, hasLength(1));

      final ref = verse.crossReferences.first;
      // <ref tgt="..."> attribute must be preserved as target.
      expect(ref.target, equals('GEN.1.1'));
      // Visible text inside <ref> must survive as label.
      expect(ref.label, contains('Gen. 1:1'));

      // Legacy plain-text list is also populated.
      expect(verse.references, hasLength(1));
    });

    test('preserves origin ref from <xo> as a separate field', () async {
      final book = await _parseFirstBook(_usfxCrossRefWithOrigin, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.crossReferences, hasLength(1));

      final ref = verse.crossReferences.first;
      expect(ref.target, equals('GEN.1.2'));
      // <xo> text must land in originRef, not be lost.
      expect(ref.originRef, isNotNull);
      expect(ref.originRef, contains('1:1'));
    });

    test('preserves divine name spans via <nd>', () async {
      final book = await _parseFirstBook(_usfxDivineName, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final divineSpans =
          verse.spans.where((s) => s.kind == VerseSpanKind.divineNameTag);
      expect(divineSpans, isNotEmpty,
          reason: 'Expected at least one divineNameTag span from <nd>');
      expect(divineSpans.first.text, contains('LORD'));
    });

    test('preserves translator addition spans via <add>', () async {
      final book = await _parseFirstBook(_usfxTranslatorAdd, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final addSpans =
          verse.spans.where((s) => s.kind == VerseSpanKind.translatorAddition);
      expect(addSpans, isNotEmpty,
          reason: 'Expected at least one translatorAddition span from <add>');
      expect(addSpans.first.text, contains('without form'));
    });

    test('preserves emphasis spans via <em>', () async {
      final book = await _parseFirstBook(_usfxEmphasis, 'USFX');
      final verse = _firstVerse(book!);
      final spans = verse!.spans.where((s) => s.kind == VerseSpanKind.emphasis);
      expect(spans, isNotEmpty,
          reason: 'Expected at least one emphasis span from <em>');
      expect(spans.first.text, contains('very'));
    });

    test('preserves bold spans via <bd>', () async {
      final book = await _parseFirstBook(_usfxBold, 'USFX');
      final verse = _firstVerse(book!);
      final spans = verse!.spans.where((s) => s.kind == VerseSpanKind.bold);
      expect(spans, isNotEmpty,
          reason: 'Expected at least one bold span from <bd>');
      expect(spans.first.text, contains('the LORD'));
    });

    test('preserves italic spans via <it>', () async {
      final book = await _parseFirstBook(_usfxItalic, 'USFX');
      final verse = _firstVerse(book!);
      final spans = verse!.spans.where((s) => s.kind == VerseSpanKind.italic);
      expect(spans, isNotEmpty,
          reason: 'Expected at least one italic span from <it>');
      expect(spans.first.text, contains('Genesis'));
    });

    test('preserves proper name spans via <pn>', () async {
      final book = await _parseFirstBook(_usfxProperName, 'USFX');
      final verse = _firstVerse(book!);
      final pnSpans =
          verse!.spans.where((s) => s.kind == VerseSpanKind.properName);
      expect(pnSpans, isNotEmpty,
          reason: 'Expected at least one properName span from <pn>');
      expect(pnSpans.first.text, contains('Abram'));
    });

    test('preserves Selah spans via <qs>', () async {
      final book = await _parseFirstBook(_usfxSelah, 'USFX');
      final verse = _firstVerse(book!);
      final selahSpans =
          verse!.spans.where((s) => s.kind == VerseSpanKind.selah);
      expect(selahSpans, isNotEmpty,
          reason: 'Expected at least one selah span from <qs>');
      expect(selahSpans.first.text, contains('Selah'));
    });

    test('preserves acrostic heading spans via <qa>', () async {
      final book = await _parseFirstBook(_usfxAcrosticHeading, 'USFX');
      final verse = _firstVerse(book!);
      final qaSpans =
          verse!.spans.where((s) => s.kind == VerseSpanKind.acrosticHeading);
      expect(qaSpans, isNotEmpty,
          reason: 'Expected at least one acrosticHeading span from <qa>');
    });

    test('preserves red-letter spans via <wj>', () async {
      final book = await _parseFirstBook(_usfxRedLetter, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final redSpans =
          verse.spans.where((s) => s.kind == VerseSpanKind.wordsOfJesus);
      expect(redSpans, isNotEmpty,
          reason: 'Expected at least one wordsOfJesus span from <wj>');
      // Span text must contain the actual words.
      expect(redSpans.first.text, contains('Blessed'));
    });

    test('preserves section heading as chapter block', () async {
      final book = await _parseFirstBook(_usfxHeading, 'USFX');

      expect(book, isNotNull);
      final chapter = book!.chapters.first;
      final headings = chapter.blocks
          .where((b) => b.kind == DocumentBlockKind.heading)
          .toList();

      expect(headings, isNotEmpty,
          reason: 'Expected a heading block from <s1>');
      expect(headings.first.text, contains('Creation'));
    });

    test('preserves non-Jesus speaker attribution in span metadata via <q who="...">', () async {
      final book = await _parseFirstBook(_usfxQuoteWho, 'USFX');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final quoteSpans = verse.spans
          .where((s) => s.metadata['quoteWho'] != null)
          .toList();

      expect(quoteSpans, isNotEmpty,
          reason: 'Expected spans with quoteWho metadata from <q who="Yahweh">');
      expect(quoteSpans.first.metadata['quoteWho'], equals('Yahweh'));
    });

    test('preserves stanza break as chapter block with stanzaBreak metadata', () async {
      final book = await _parseFirstBook(_usfxStanzaBreak, 'USFX');

      expect(book, isNotNull);
      final chapter = book!.chapters.first;
      final stanzaBlocks = chapter.blocks
          .where((b) => b.metadata['stanzaBreak'] == 'true')
          .toList();

      expect(stanzaBlocks, isNotEmpty,
          reason: 'Expected a block with stanzaBreak=true from <b>');
      expect(stanzaBlocks.first.metadata['sourceTag'], equals('b'));
    });

    test('preserves word metadata (Strong\'s, lemma, morph) from <w>', () async {
      final book = await _parseFirstBook(_usfxWordMetadata, 'USFX');

      expect(book, isNotNull);
      final verse = _firstVerse(book!);
      expect(verse, isNotNull);

      final wordSpans = verse!.spans
          .where((s) => s.kind == VerseSpanKind.word)
          .toList();

      expect(wordSpans, isNotEmpty,
          reason: 'Expected a word span from <w> tag');
      expect(wordSpans.first.metadata['strongs'], equals('H7225'));
      expect(wordSpans.first.metadata['lemma'], equals('reshith'));
      expect(wordSpans.first.metadata['morph'], equals('HNcfsa'));
    });
  });

  // -------------------------------------------------------------------------
  // OSIS
  // -------------------------------------------------------------------------

  group('OSIS parser', () {
    test('parses basic verse text', () async {
      final book = await _parseFirstBook(_osisBasic, 'OSIS');

      expect(book, isNotNull);
      expect(book!.id, equals('gen'));
      expect(book.chapters, hasLength(1));

      final verse = _firstVerse(book);
      expect(verse, isNotNull);
      expect(verse!.num, equals(1));
      expect(verse.chapterNum, equals(1));
      expect(verse.text, contains('beginning'));
    });

    test('preserves footnote from <note>', () async {
      final book = await _parseFirstBook(_osisFootnote, 'OSIS');
      final verse = _firstVerse(book!);

      expect(verse!.footnotes, hasLength(1));

      final fn = verse.footnotes.first;
      expect(fn.text, contains('note about this verse'));
      // The n="" attribute is stored as both label and marker.
      expect(fn.label, equals('a'));
      // bodyText is set to the full note text as a convenience field.
      expect(fn.bodyText, isNotNull);
      expect(fn.bodyText, contains('note about this verse'));

      // Legacy plain-text list is also populated.
      expect(verse.notes, hasLength(1));
    });

    test('preserves standalone cross-reference from <reference>', () async {
      final book = await _parseFirstBook(_osisCrossRef, 'OSIS');
      final verse = _firstVerse(book!);

      expect(verse!.crossReferences, hasLength(1));

      final ref = verse.crossReferences.first;
      expect(ref.target, equals('Gen.1.1'));
      expect(ref.label, contains('Gen 1:1'));

      // Legacy plain-text list is also populated.
      expect(verse.references, hasLength(1));
    });

    test('preserves origin ref from <reference type="source"> as a separate field', () async {
      final book = await _parseFirstBook(_osisCrossRefWithOrigin, 'OSIS');
      final verse = _firstVerse(book!);

      // The source reference must not create a CrossReference — only the target does.
      expect(verse!.footnotes, hasLength(1));
      final fn = verse.footnotes.first;
      expect(fn.references, hasLength(1));

      final ref = fn.references.first;
      expect(ref.target, equals('Gen.1.2'));
      // <reference type="source"> text must land in originRef.
      expect(ref.originRef, isNotNull);
      expect(ref.originRef, contains('1:1'));
    });

    test('preserves divine name spans via <divineName>', () async {
      final book = await _parseFirstBook(_osisDivineName, 'OSIS');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final divineSpans =
          verse.spans.where((s) => s.kind == VerseSpanKind.divineNameTag);
      expect(divineSpans, isNotEmpty,
          reason: 'Expected at least one divineNameTag span from <divineName>');
      expect(divineSpans.first.text, contains('LORD'));
    });

    test('preserves red-letter spans via <q who="Jesus">', () async {
      final book = await _parseFirstBook(_osisRedLetter, 'OSIS');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final redSpans =
          verse.spans.where((s) => s.kind == VerseSpanKind.wordsOfJesus);
      expect(redSpans, isNotEmpty,
          reason: 'Expected wordsOfJesus span from <q who="Jesus">');
      expect(redSpans.first.text, contains('Blessed'));
    });

    test('preserves bold spans via <hi type="bold">', () async {
      final book = await _parseFirstBook(_osisHiBold, 'OSIS');
      final verse = _firstVerse(book!);
      final spans = verse!.spans.where((s) => s.kind == VerseSpanKind.bold);
      expect(spans, isNotEmpty,
          reason: 'Expected at least one bold span from <hi type="bold">');
      expect(spans.first.text, contains('the LORD'));
    });

    test('preserves italic spans via <hi type="italic">', () async {
      final book = await _parseFirstBook(_osisHiItalic, 'OSIS');
      final verse = _firstVerse(book!);
      final spans = verse!.spans.where((s) => s.kind == VerseSpanKind.italic);
      expect(spans, isNotEmpty,
          reason: 'Expected at least one italic span from <hi type="italic">');
      expect(spans.first.text, contains('Genesis'));
    });

    test('preserves chapter title as heading block', () async {
      final book = await _parseFirstBook(_osisTitle, 'OSIS');

      expect(book, isNotNull);
      final chapter = book!.chapters.first;
      final headings = chapter.blocks
          .where((b) => b.kind == DocumentBlockKind.heading)
          .toList();

      expect(headings, isNotEmpty,
          reason: 'Expected a heading block from <title>');
      expect(headings.first.text, contains('Creation'));
    });

    test('preserves stanza break block with stanzaBreak metadata from empty <l />', () async {
      final book = await _parseFirstBook(_osisStanzaBreak, 'OSIS');

      expect(book, isNotNull);
      final chapter = book!.chapters.first;
      final stanzaBlocks = chapter.blocks
          .where((b) => b.metadata['stanzaBreak'] == 'true')
          .toList();

      expect(stanzaBlocks, isNotEmpty,
          reason: 'Expected a block with stanzaBreak=true from empty <l />');
    });

    test('preserves non-Jesus speaker attribution in span metadata via <q who="...">', () async {
      final book = await _parseFirstBook(_osisQuoteWho, 'OSIS');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final quoteSpans = verse.spans
          .where((s) => s.metadata['quoteWho'] != null)
          .toList();

      expect(quoteSpans, isNotEmpty,
          reason: 'Expected spans with quoteWho metadata from <q who="Yahweh">');
      expect(quoteSpans.first.metadata['quoteWho'], equals('Yahweh'));
    });

    test('preserves OSIS tables as table and tableRow blocks', () async {
      final book = await _parseFirstBook(_osisTable, 'OSIS');

      expect(book, isNotNull);
      final chapter = book!.chapters.first;
      final tableContainers = chapter.blocks
          .where((b) => b.kind == DocumentBlockKind.table)
          .toList();
      final tableBlocks = chapter.blocks
          .where((b) => b.kind == DocumentBlockKind.tableRow)
          .toList();

      expect(tableContainers, hasLength(1),
          reason: 'Expected one table container block');
      expect(tableContainers.first.metadata['rowCount'], equals('2'));
      expect(tableBlocks, hasLength(2),
          reason: 'Expected one chapter block per OSIS table row');
      expect(tableBlocks.first.text, equals('Day One'));
      expect(tableBlocks.first.metadata['tableType'], equals('x-study'));
      expect(tableBlocks.first.metadata['rowType'], equals('label'));
      expect(tableBlocks.first.metadata['cellCount'], equals('2'));
      expect(tableBlocks.first.metadata['cells'], equals('Day\tOne'));
      expect(tableBlocks.first.metadata['rowIndex'], equals('1'));
      expect(tableBlocks.last.text, equals('Light Created'));
      expect(tableBlocks.last.metadata['rowIndex'], equals('2'));
    });

    test('preserves word metadata (lemma, morph) from <w>', () async {
      final book = await _parseFirstBook(_osisWordMetadata, 'OSIS');

      expect(book, isNotNull);
      final verse = _firstVerse(book!);
      expect(verse, isNotNull);

      final wordSpans = verse!.spans
          .where((s) => s.kind == VerseSpanKind.word)
          .toList();

      expect(wordSpans, isNotEmpty,
          reason: 'Expected a word span from <w> tag');
      expect(wordSpans.first.metadata['lemma'], equals('strong:H7225'));
      expect(wordSpans.first.metadata['morph'], equals('HNcfsa'));
    });
  });

  // -------------------------------------------------------------------------
  // Zefania
  // -------------------------------------------------------------------------

  group('Zefania parser', () {
    test('parses basic verse text', () async {
      final book = await _parseFirstBook(_zefaniaBasic, 'ZEFANIA');

      expect(book, isNotNull);
      expect(book!.chapters, hasLength(1));

      final verse = _firstVerse(book);
      expect(verse, isNotNull);
      expect(verse!.num, equals(1));
      expect(verse.chapterNum, equals(1));
      expect(verse.text, contains('beginning'));
    });

    test('preserves footnote from <NOTE>', () async {
      final book = await _parseFirstBook(_zefaniaFootnote, 'ZEFANIA');
      final verse = _firstVerse(book!);

      expect(verse!.footnotes, hasLength(1));

      final fn = verse.footnotes.first;
      expect(fn.text, contains('footnote about creation'));
      // bodyText is set to the full note text as a convenience field.
      expect(fn.bodyText, isNotNull);
      expect(fn.bodyText, contains('footnote about creation'));

      // Legacy plain-text list is also populated.
      expect(verse.notes, hasLength(1));
    });

    test('preserves cross-reference from <XREF fscope="...">', () async {
      final book = await _parseFirstBook(_zefaniaCrossRef, 'ZEFANIA');
      final verse = _firstVerse(book!);

      expect(verse!.crossReferences, hasLength(1));

      final ref = verse.crossReferences.first;
      expect(ref.target, equals('Gen.1.1'));
      expect(ref.label, contains('Gen 1:1'));

      // Legacy plain-text list is also populated.
      expect(verse.references, hasLength(1));
    });

    test('preserves red-letter spans via <STYLE css="wj">', () async {
      final book = await _parseFirstBook(_zefaniaRedLetter, 'ZEFANIA');
      final verse = _firstVerse(book!);

      expect(verse!.spans, isNotEmpty);
      final redSpans =
          verse.spans.where((s) => s.kind == VerseSpanKind.wordsOfJesus);
      expect(redSpans, isNotEmpty,
          reason: 'Expected wordsOfJesus span from <STYLE css="wj">');
      expect(redSpans.first.text, contains('Blessed'));
    });
  });
}
