# Bible Parser Todo Status

## Goal
Track parser work needed to move from plain-text extraction to a richer Bible-data model that can power a proper Bible app.

Status meanings:
- `done`: implemented and verified in current code
- `partial`: some support exists, but output is incomplete or lossy
- `todo`: not implemented yet

## Operating Instructions
- Update this file whenever a meaningful parser task starts or finishes.
- Before making parser changes, add the exact active slice to `Current Status`.
- After finishing the change, move that slice out of `in_progress` immediately and record the result as `done`.
- Keep `Current Status` disciplined:
  - only list truly active or still-unresolved parser work
  - do not leave finished parser slices there
  - do not use it for broad long-term vision that belongs in backlog sections
- Keep `Current Status` short enough to scan quickly.
- Keep `Priority Backlog` for longer-lived parser goals and unfinished categories.
- If more than one line says roughly the same thing, collapse them into one clearer line.
- When a parser slice is verified, add or update a focused test before marking it done.
- After a meaningful verified parser slice, create a focused commit.

## Completed Recently

- `done` Classified OSIS paragraph markers like `type="x-ms"` as heading-like structural blocks instead of generic prose, so major section markers from real files survive with better semantics.
- `done` Preserved more OSIS title metadata such as `short` and `canonical` so title blocks now keep source navigation/layout hints that real OSIS files already expose.
- `done` Preserved OSIS `<lb />` break markers as structured layout blocks with source-tag metadata instead of dropping those source line breaks before the reader can use them.
- `done` Preserved USFX list-style block tags such as `li1`, `li2`, and `ili1` as structured blocks with source-tag and level metadata instead of flattening those list sections away.
- `done` Preserved OSIS non-verse `<list>` / `<item>` content as structured blocks with list, item, section, and source-tag metadata instead of flattening those list sections away.
- `done` Fixed OSIS nested section `div` handling so inner `div` blocks no longer incorrectly close the book, and titles/paragraphs inside those sections now preserve section metadata for downstream rendering.

## Current Status

- `partial` Phase 1 shared rich-content model types now exist in code, and all three main parser formats now populate part of them, but output is still incomplete and format fidelity is still lossy.
- `in_progress` USFX, OSIS, and Zefania now all preserve some structured spans, notes, references, front matter, headings, paragraph starts, and layout metadata, but the output is still incomplete and source fidelity is still lossy.
- `in_progress` The active parser gap is remaining non-verse layout structure beyond the current title, paragraph, list, line-group, speaker, caption, simple break, nested section, basic list-item, line-break, title-metadata, and major-section paragraph handling, especially where source files expose richer sectional tags than the shared model keeps.

| Feature | USFX | OSIS | Zefania | Notes |
|---|---|---|---|---|
| Book/chapter/verse parsing | done | done | done | Core extraction works in all three parsers. |
| Auto format detection | done | done | done | Detection exists in `BibleParser`. |
| Footnotes | partial | partial | partial | All three formats now preserve plain strings plus basic structured footnotes, but still do not capture every nested note detail. |
| Cross references | partial | partial | partial | All three formats now preserve plain strings plus basic structured cross references. |
| Red-letter text | partial | partial | partial | Zefania can now infer red-letter style from style metadata where the source uses that convention. |
| Poetry / quoted line structure | partial | partial | partial | USFX, OSIS, and Zefania now preserve more source-driven poetry/quote line starts, including OSIS line groups, but coverage is still incomplete and not lossless. |
| Paragraph boundaries | partial | partial | partial | All three now preserve chapter paragraph-start markers in the shared block model when the source exposes them, but this is still not full layout fidelity. |
| Section headings / titles | partial | partial | partial | All three formats now preserve more heading/title blocks, including source-tag metadata in several front-matter cases, but coverage is still incomplete. |
| Word-level metadata | partial | partial | partial | Zefania can now preserve some style/`gr` metadata, though it is less explicit than USFX/OSIS word markup. |
| Translator additions | partial | partial | partial | Zefania can now infer translator-addition spans from italic/add-style conventions where present. |
| Inline formatting spans | partial | partial | partial | Canonical span output exists in all three formats for some semantics, but broader style coverage is still not modeled. |
| Introductions / front matter | partial | partial | partial | OSIS now preserves pre-chapter intro paragraphs and Zefania preserves `PROLOG`/`CAPTION` metadata alongside the existing USFX front-matter support. |
| Structured notes model | partial | partial | partial | Structured note/reference objects now exist in all three formats, but still coexist with legacy plain-text lists and remain lossy. |
| Lossless round-trip friendliness | todo | todo | todo | Current parser is optimized for reading, not preservation. |
| Format-fidelity target | todo | todo | todo | The long-term goal is to preserve as much meaningful structure as practical across all supported formats. |
| Shared rich-content model types | done | done | done | Canonical rich-content types now exist; parser behavior still needs to populate them. |

## Priority Backlog

### 1. Footnotes
Status: `partial`

What exists now:
- USFX `<f>` content is appended into `Verse.notes`.
- USFX also creates basic `Footnote` objects with marker, label, and text.

What is missing:
- Preserve footnote caller/marker.
- Preserve nested note parts such as `fr`, `ft`, and nested references.
- Avoid flattening everything into one opaque string.

Recommended next output shape:
- Introduce a structured footnote model per verse.
- Keep the plain string list only as a compatibility fallback if needed.

### 2. Red-Letter Text
Status: `partial`

Why it matters:
- Many Bible readers want the words of Jesus styled differently.
- Local example XML already contains the source markers.

Observed source markers:
- USFX: `<wj>`
- OSIS: `<q who="Jesus">`

Recommended next output shape:
- Add verse-level inline spans or tokens with a `wordsOfJesus` / `redLetter` style flag.
- Keep `Verse.text` as a flattened text projection for search and simple UI.

### 3. Cross-References
Status: `partial`

What exists now:
- USFX captures text from `<x>`.
- USFX also creates basic `CrossReference` objects, including `ref tgt="..."` targets when present.

What is missing:
- Preserve target refs such as `tgt="EZK.10.1"`.
- Preserve multiple references separately.
- Normalize references into a structured shape instead of a single flattened string.

### 4. Poetry and Quote Structure
Status: `partial`

Why it matters:
- Psalms, prophets, beatitudes, and many discourse sections render badly when flattened.

Observed source markers:
- USFX: `<q level="...">`
- OSIS: quote structures, including `who="Jesus"` in some files

Recommended next output shape:
- Add paragraph/block metadata or inline block tokens.
- Preserve quote level / indentation information.

### 5. Word-Level Metadata
Status: `partial`

Why it matters:
- Strong's numbers, lexicon links, and advanced study tools depend on this.

Observed source markers:
- USFX: `<w s="H7225">beginning</w>`

Recommended next output shape:
- Add inline tokens for words with optional source metadata.

### 6. Translator Additions and Formatting
Status: `partial`

Observed source markers:
- USFX: `<add>`
- likely other formatting tags depending on source file

Recommended next output shape:
- Preserve semantic styles in spans instead of collapsing them into plain text.

### 7. Introductions and Front Matter
Status: `partial`

Why it matters:
- Real Bible XML files include prefaces, toc labels, headings, and book-level front matter.
- That content is useful in a serious Bible app and is currently being dropped.

Observed source markers:
- USFX: `FRT`, `h`, `toc`, and related intro/front-matter tags
- OSIS: `title` and other section/front-matter structures

Recommended next output shape:
- Add first-class parser output for introduction/front-matter content instead of treating everything as book/chapter/verse only.

What exists now:
- USFX preserves basic `toc` labels and pre-chapter heading/paragraph blocks as structured content.
- OSIS preserves book titles as introduction blocks and chapter titles as chapter blocks.
- Zefania preserves `PROLOG` as introduction blocks and `CAPTION` as chapter heading blocks.

What is missing:
- More complete source coverage
- Better distinction between Bible-level and book-level front matter
- Matching support in OSIS and Zefania

### 8. Full Format Fidelity
Status: `todo`

Goal:
- Preserve as much meaningful structure from USFX, OSIS, and Zefania as practical, then normalize it into shared parser/app concepts.

Important constraint:
- Full fidelity is a program of work, not a one-step feature.
- The parser should not expose every source tag directly to the UI; it should map source tags into canonical concepts first.

## Suggested Implementation Order
1. Expand the `Verse` model so it can hold structured inline spans and structured annotations.
2. Add first-class support for introduction/front-matter content so the parser is no longer limited to book/chapter/verse only.
3. Add feature tests with real XML snippets for:
   - USFX footnotes
   - USFX preface/front matter
   - USFX `<wj>`
   - OSIS `<q who="Jesus">`
   - OSIS titles/front matter
   - USFX `<w s="...">`
   - USFX `<q level="...">`
4. Upgrade the USFX parser first, because it already handles notes/references and local app assets use it heavily.
5. Upgrade the OSIS parser second for red-letter, title, and note/reference semantics.
6. Improve Zefania style coverage only after you confirm which style conventions appear in the real source files you care about.
7. Only then decide how much of the richer model should be stored in `BibleRepository` and app-side databases.

## App Integration Impact
Any parser upgrade here will likely require matching updates in `basic_bible`, especially:
- `basic_bible/lib/src/models/bible_models.dart`
- `basic_bible/lib/src/repositories/app_bible_repository.dart`
- `basic_bible/lib/src/services/app_database.dart`

The current app can now render some rich inline formatting faithfully, but it still needs better UI for front matter and structured notes.
