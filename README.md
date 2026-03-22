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
