# Bible Parser Flutter

`bible_parser_flutter` is the parser package used by the app in this workspace. It parses Bible XML files into a shared Dart model that is now aimed at real Bible-reader use, not only plain-text verse extraction.

This README is intentionally status-focused. It should describe what the parser actually does now.

## Current Parser Status

### Working now

- Parse Bible XML in:
  - USFX
  - OSIS
  - Zefania
- Auto-detect the format through `BibleParser`.
- Stream parsed `Book` objects from `BibleParser.books`.
- Expose parsed `Book`, `Chapter`, and `Verse` data through one shared model.
- Preserve plain verse text for simple reading/search use.
- Preserve part of the richer parser model, including:
  - structured verse spans
  - structured footnotes
  - structured cross-references
  - TOC labels
  - book introduction blocks
  - chapter document blocks
  - some paragraph / line / poetry metadata
- Provide a `BibleRepository` helper for SQLite-backed caching and querying.

### Partial / still in progress

- Rich parsing is active across USFX, OSIS, and Zefania, but it is still partial and lossy.
- Footnotes and cross-references are preserved structurally in part, but nested/source-specific detail is still incomplete.
- Front matter and non-verse layout blocks are preserved much better than before, but still not comprehensively.
- Inline anchor placement for note/reference markers is improved but not fully source-perfect.
- The parser is optimized for reading use, not lossless round-tripping.

### Not claimed yet

- Full format fidelity for every supported XML tag
- Lossless round-trip preservation
- Complete Bible-level front-matter modeling
- Complete source-specific layout preservation across all supported files

## Supported Data Direction

The parser is no longer only about flattened strings. The active shared model now includes richer concepts such as:

- `VerseSpan`
- `Footnote`
- `CrossReference`
- `TocLabel`
- `DocumentBlock`

These types let the app preserve more meaning from the source files instead of flattening everything immediately.

## Example: Direct Parsing

```dart
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

Future<void> parseBible(String xmlString) async {
  final parser = BibleParser.fromString(xmlString);

  await for (final book in parser.books) {
    print('${book.title} (${book.id})');

    for (final chapter in book.chapters) {
      for (final verse in chapter.verses) {
        print('${verse.bookId} ${verse.chapterNum}:${verse.num}');
        print(verse.text);

        if (verse.footnotes.isNotEmpty) {
          print('Footnotes: ${verse.footnotes.length}');
        }

        if (verse.spans.isNotEmpty) {
          print('Rich spans: ${verse.spans.length}');
        }
      }
    }
  }
}
```

## Example: Repository Caching

```dart
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

Future<void> cacheBible(String xmlString) async {
  final repository = BibleRepository.fromString(
    xmlString: xmlString,
    format: 'USFX',
  );

  await repository.initialize('example_bible.db');

  final books = await repository.getBooks();
  final verses = await repository.getVerses('gen', 1);

  print('Books: ${books.length}');
  print('Genesis 1 verses: ${verses.length}');

  await repository.close();
}
```

## Format Feature Support

The tables below map what each supported XML format can express against what the parser currently preserves.

**Status key:**
- ✅ Supported — preserved in the shared model
- ⚠️ Partial — some coverage but incomplete or lossy
- ❌ Not yet — present in the source format, not yet modeled

### USFX

| Feature | XML Tag(s) | Status | Notes |
|---|---|---|---|
| Books / chapters / verses | `<book>` `<c>` `<v>` | ✅ | Core extraction |
| Words of Jesus | `<wj>` | ✅ | Preserved as `wordsOfJesus` span kind |
| Translator additions | `<add>` | ✅ | Preserved as `translatorAddition` span kind |
| Divine name (LORD) | `<nd>` | ✅ | Preserved as `divineNameTag` span kind |
| Footnotes | `<f caller="...">` | ⚠️ | Structured `Footnote` objects created |
| Footnote label (verse ref) | `<fr>` | ✅ | Preserved as `label` field |
| Footnote body text | `<ft>` | ✅ | Preserved as `bodyText` field |
| Footnote quote / alt quote | `<fq>` `<fqa>` | ✅ | Preserved as `quotedText` field |
| Cross-references | `<x caller="...">` | ⚠️ | Structured `CrossReference` objects created |
| Cross-ref origin | `<xo>` | ✅ | Preserved as `originRef` field |
| Cross-ref target | `<ref tgt="...">` | ✅ | Preserved as `target` field |
| Poetry / quote lines | `<q level="...">` | ⚠️ | Level tracked; stanza grouping partial |
| Quote attribution | `<q who="...">` | ❌ | `who` attribute not captured |
| Strong's word metadata | `<w s="...">` | ⚠️ | Stored in span `metadata` map |
| Word morphology | `<w m="...">` | ❌ | Attribute dropped |
| Word lemma | `<w l="...">` | ❌ | Attribute dropped |
| Book heading | `<h>` | ✅ | Preserved as introduction block |
| TOC labels | `<toc level="1/2/3">` | ✅ | Preserved as `TocLabel` objects |
| Section headings | `<s>` `<s1>` `<s2>` | ⚠️ | Captured as heading blocks; level partial |
| Paragraph starts / breaks | `<p>` `<b>` | ⚠️ | Preserved as chapter-level document blocks |
| Intro paragraphs | `<ip>` `<imt>` `<is>` | ✅ | Captured as introduction blocks |
| Intro outline entries | `<io1>` `<io2>` | ✅ | Captured as introduction blocks with level |
| Chapter description | `<cd>` | ✅ | Captured as chapter-level block |
| List items | `<li1>` `<li2>` `<li3>` | ✅ | Preserved as blocks with level metadata |
| Intro list items | `<ili1>` `<ili2>` | ✅ | Preserved as blocks |
| Proper name | `<pn>` | ✅ | Preserved as `properName` span kind |
| Selah / music cue | `<qs>` | ✅ | Preserved as `selah` span kind |
| Acrostic heading | `<qa>` | ✅ | Preserved as `acrosticHeading` span kind |
| Inline emphasis | `<em>` `<bd>` `<it>` | ❌ | Merged into plain text |

### OSIS

| Feature | XML Tag(s) | Status | Notes |
|---|---|---|---|
| Books / chapters / verses | `<div>` `<chapter>` `<verse>` | ✅ | Includes milestone sID/eID style |
| Words of Jesus | `<q who="Jesus">` | ✅ | Preserved as `wordsOfJesus` span kind |
| Translator additions | `<transChange type="added">` | ✅ | Preserved as `translatorAddition` span kind |
| Divine name (LORD) | `<divineName>` | ✅ | Preserved as `divineNameTag` span kind |
| Footnotes | `<note type="footnote">` | ⚠️ | `bodyText` populated from note text; nested `<q>` parts not yet separated |
| Study notes | `<note type="study">` | ❌ | Not distinguished from footnotes |
| Cross-references | `<note type="crossReference">` | ⚠️ | Structured; cross-ref-only notes (no plain text) handled |
| Cross-ref origin | `<reference type="source">` | ✅ | Preserved as `originRef` on `CrossReference` |
| Reference targets | `<reference osisRef="...">` | ⚠️ | Preserved when present |
| Book title | `<title type="main">` | ✅ | Preserved as introduction block |
| Section heading | `<title type="section">` | ⚠️ | Captured as heading blocks |
| Running head | `<title type="runningHead">` | ❌ | Dropped |
| Canonical title | `<title canonical="true">` | ✅ | Metadata preserved |
| Short title | `<title short="...">` | ✅ | Metadata preserved |
| Psalm superscription | `<title type="psalm">` | ⚠️ | `beforeVerse` flag tracked; positioning partial |
| Poetry line group | `<lg>` | ✅ | Preserved; empty lines become stanza-break blocks |
| Poetry line | `<l level="...">` | ⚠️ | Level tracked; full indentation not yet rendered |
| Paragraph | `<p>` | ⚠️ | Preserved as `beforeVerse` document blocks |
| Line break | `<lb />` | ✅ | Preserved as structural blocks |
| Speaker attribution | `<speaker>` | ✅ | Preserved as block metadata |
| Tables | `<table>` `<row>` `<cell>` | ❌ | Dropped |
| Lists / items | `<list>` `<item>` | ✅ | Preserved as structured blocks |
| Word metadata | `<w>` | ⚠️ | Captured in span metadata |
| Strong's numbers | `<w lemma="strong:H1">` | ⚠️ | Preserved; attribute format differs from USFX |
| Morphology | `<w morph="...">` | ❌ | Dropped |
| Nested section div | `<div type="section">` | ✅ | Tracked with metadata stack |
| Book introduction | `<div type="introduction">` | ⚠️ | Pre-chapter intro paragraphs preserved |
| Major section marker | `<div type="x-ms">` | ✅ | Classified as heading-like block |
| Colophon | `<div type="colophon">` | ❌ | Dropped |
| Catchword | `<catchWord>` | ❌ | Dropped |
| Gloss | `<gloss>` | ❌ | Dropped |

### Zefania

| Feature | XML Tag(s) | Status | Notes |
|---|---|---|---|
| Books / chapters / verses | `<BIBLEBOOK>` `<CHAPTER>` `<VERS>` | ✅ | Core extraction |
| Bible metadata | `<INFORMATION>` | ✅ | Carried as front-matter blocks on first book |
| Book prolog | `<PROLOG>` | ✅ | Preserved as introduction block |
| Chapter caption | `<CAPTION>` | ✅ | Preserved as chapter heading block |
| Footnotes | `<NOTE>` | ⚠️ | Partially structured; nested detail incomplete |
| Cross-references | `<XREF>` | ⚠️ | Partially structured |
| Styled text | `<STYLE type="...">` | ⚠️ | Span kind inferred from type name; heuristic-based |
| Words of Jesus | (via `<STYLE>`) | ⚠️ | Inferred from style metadata; not an explicit tag |
| Translator additions | (via `<STYLE>`) | ⚠️ | Inferred from italic/add-style conventions |
| Paragraph | `<PARA>` | ✅ | Preserved as document block |
| Line break | `<BR />` | ❌ | Dropped |
| Grammar metadata | `<gr>` | ⚠️ | Some style metadata preserved |

## Practical Limits

- This package is still best described as a reading-oriented parser with partial rich-format support.
- It has been exercised mainly against the XML files used in this workspace and the example/open-bibles-style files already in the repo.
- If you need exact preservation of every source-specific XML construct, this package is not done yet.

## Example App

See the `example/` folder for the package example app and local parser experiments.

## License

This project is licensed under the MIT License. See `LICENSE`.

## Acknowledgments

Inspired by the Ruby [bible_parser](https://github.com/seven1m/bible_parser) library.
