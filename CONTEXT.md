# Bible Parser Flutter Context

## Purpose
`bible_parser_flutter` is the local parser package used by the app at `basic_bible/`.

Its job is to parse Bible XML into app-usable Dart models. Right now it supports:

- USFX
- OSIS
- Zefania

The package is already usable for plain book/chapter/verse extraction, but it does not yet preserve all of the structured Bible metadata that richer Bible apps usually need.

## Public Surface
- `BibleParser`
  - Detects or accepts a format.
  - Streams parsed `Book` objects through `books`.
  - Streams parsed `Verse` objects through `verses`.
- `BibleRepository`
  - Optional SQLite-backed repository over parsed data.
  - Stores books and verses for repeated lookup and text search.
- Models:
  - `Book`
  - `Chapter`
  - `Verse`

## Current Model Shape

### `Verse`
`Verse` currently exposes:

- `num`
- `chapterNum`
- `text`
- `bookId`
- `notes`
- `references`

This is important: the model already has room for footnotes and cross-references, but it does not yet have a structured way to preserve richer formatting or annotations such as:

- red-letter segments / words of Jesus
- paragraph boundaries
- poetry/quote line structure
- section headings
- translator additions
- word-level metadata such as Strong's numbers
- inline formatting spans such as italic/bold/small caps

## Current Parser Behavior By Format

### USFX
`lib/src/parsers/usfx_parser.dart` is the most feature-aware parser in the package today.

Current behavior:
- Parses books, chapters, and verses.
- Captures `<f>` content into `Verse.notes`.
- Captures `<x>` content into `Verse.references`.
- Includes normal inline text in `Verse.text`.

Current limitations:
- Footnotes are flattened to plain strings instead of structured objects.
- `<ref>` inside notes/references is reduced to text only.
- `<wj>` red-letter text is not preserved as a distinct style or segment.
- `<q>` poetic/quote structure is not preserved.
- `<w>` word-level metadata such as Strong's numbers is ignored.
- `<add>` translator-added words are merged into plain text without annotation.
- Headings, paragraph markers, table data, toc metadata, and similar structure are ignored for output.

### OSIS
`lib/src/parsers/osis_parser.dart` currently focuses on plain-text verse extraction.

Current behavior:
- Parses books, chapters, and verses.
- Handles both normal OSIS tags and milestone-style `sID` / `eID` chapter and verse boundaries.
- Produces plain `Verse.text`.

Current limitations:
- Does not currently capture notes or cross-references into `Verse.notes` / `Verse.references`.
- Does not preserve red-letter markers such as `<q who="Jesus">`.
- Does not preserve paragraph, quote, title, or section structure.
- Does not preserve inline semantic tags often found in OSIS.

### Zefania
`lib/src/parsers/zefania_parser.dart` is currently the simplest parser.

Current behavior:
- Parses books, chapters, and verses.
- Produces plain verse text.

Current limitations:
- Does not preserve notes, references, formatting, or richer structure.
- Support is effectively basic extraction rather than full-feature parsing.

## Real Input Features Seen In Local Files
The local XML files already show that richer metadata exists and should be considered first-class parser work.

Examples seen in project assets:
- USFX footnotes via `<f>`
- USFX cross-references via `<x>` and nested `<ref>`
- USFX word-level tags via `<w s="...">`
- USFX translator additions via `<add>`
- USFX poetic / quoted lines via `<q>`
- USFX toc / heading-like metadata via `<toc>` and related content

Examples seen in parser example assets:
- USFX red-letter content via `<wj>`
- OSIS words of Jesus via `<q who="Jesus">`

## Key Architectural Constraint
The current package returns a flattened `Verse.text` plus optional string lists for notes and references. That is enough for simple reading and search, but it is too lossy for rendering richer Bible UX.

If the goal is to support:
- footnote popovers
- red-letter text
- poetry indentation
- semantic formatting
- richer export/import fidelity

then the parser will need a structured inline representation instead of only a single flattened `text` field.

## Recommended Direction
Treat the next parser phase as "preserve semantics, not just plain text."

Recommended design direction:
- Keep `Verse.text` for simple consumers and search.
- Add structured annotation/span support alongside it.
- Extend parsing incrementally, starting with the features already present in local XML:
  - footnotes
  - cross-references
  - red-letter text
  - poetry/quote blocks
  - word metadata
  - translator-added words

## Practical Starting Points
- Start with `lib/src/verse.dart` because the current model is too small for richer formatting.
- Then inspect:
  - `lib/src/parsers/usfx_parser.dart`
  - `lib/src/parsers/osis_parser.dart`
  - `lib/src/parsers/zefania_parser.dart`
- Use the example assets and tests as fixtures when adding structured parsing.
- Prefer feature tests based on real XML snippets before changing the parser internals.

## Current Reality Check
- Footnotes are partially supported today only in the USFX parser.
- Cross-references are partially supported today only in the USFX parser.
- Red-letter text is not preserved as red-letter metadata in any parser.
- The parser package is strongest for plain text extraction and weakest for rich Bible formatting semantics.
