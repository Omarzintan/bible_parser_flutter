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

- `done` Refreshed the public parser README so it now describes the current partial rich-content parser, shared model direction, practical limits, and the direct-parsing / repository-caching usage paths more honestly.
- `done` Preserved top-level Zefania `INFORMATION` metadata as carried front-matter blocks with `scope: bible` so source title/description metadata no longer disappears completely.
- `done` Preserved `beforeVerse` metadata on OSIS chapter-level titles that appear before verse 1, so Psalm superscriptions and similar source titles can be positioned more reliably by the reader.
- `done` Preserved empty OSIS poetry-line markers inside `<lg><l /></lg>` blocks by recording stanza-break metadata instead of dropping those layout cues entirely.
- `done` Classified OSIS paragraph markers like `type="x-ms"` as heading-like structural blocks instead of generic prose, so major section markers from real files survive with better semantics.
- `done` Preserved more OSIS title metadata such as `short` and `canonical` so title blocks now keep source navigation/layout hints that real OSIS files already expose.
- `done` Preserved OSIS `<lb />` break markers as structured layout blocks with source-tag metadata instead of dropping those source line breaks before the reader can use them.
- `done` Preserved USFX list-style block tags such as `li1`, `li2`, and `ili1` as structured blocks with source-tag and level metadata instead of flattening those list sections away.
- `done` Preserved OSIS non-verse `<list>` / `<item>` content as structured blocks with list, item, section, and source-tag metadata instead of flattening those list sections away.
- `done` Fixed OSIS nested section `div` handling so inner `div` blocks no longer incorrectly close the book, and titles/paragraphs inside those sections now preserve section metadata for downstream rendering.

## Current Status

- `partial` Phase 1 shared rich-content model types now exist in code, and all three main parser formats now populate part of them, but output is still incomplete and format fidelity is still lossy.
- `in_progress` USFX, OSIS, and Zefania now all preserve some structured spans, notes, references, front matter, headings, paragraph starts, and layout metadata, but the output is still incomplete and source fidelity is still lossy.
- `in_progress` The active parser gap is remaining non-verse layout structure beyond the current title, paragraph, list, line-group, speaker, caption, simple break, nested section, basic list-item, line-break, title-metadata, major-section paragraph, empty poetry-line, chapter-title placement, and carried Zefania `INFORMATION` handling, especially where source files expose richer sectional tags than the shared model keeps.

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

## Remaining Work, Written Out

### Parser: What is still left to add

#### A. Finish structured footnotes
What still needs to happen:
- Preserve the real footnote caller location, not just the final text value.
- Keep nested footnote parts separate where the source distinguishes them, such as:
  - reference prefix
  - note body
  - nested references
  - optional labels or markers
- Preserve note order exactly as it appears in the source.
- Stop relying on plain `Verse.notes` as the main output shape.

What "done" should mean:
- A verse with multiple notes keeps them as distinct structured note objects.
- A note with nested references keeps those references structurally.
- The parser still exposes a plain-text fallback only for compatibility.

#### B. Finish structured cross-references
What still needs to happen:
- Preserve every cross-reference target when the source provides one.
- Keep multiple references separate instead of flattening them into one string.
- Preserve any visible marker or label tied to the reference.
- Keep reference ordering stable so the app can render them in the right place.

What "done" should mean:
- Each cross-reference survives as its own object with label, marker, and target when present.
- Reference targets like `JHN.1.1` or `EZK.10.1` are preserved reliably across formats.

#### C. Improve inline note/reference anchors
What still needs to happen:
- Preserve anchor positions more accurately for inline notes and references.
- Reduce cases where the parser has to guess the attachment point.
- Keep the marker on the exact span or boundary it belongs to when the XML makes that possible.

What "done" should mean:
- Inline note letters and reference letters can be rendered beside the right words more consistently.
- The parser output is stable enough that the app does not need to guess marker placement as often.

#### D. Finish red-letter support
What still needs to happen:
- Preserve words-of-Jesus spans everywhere the source marks them.
- Avoid losing red-letter boundaries when they overlap with quote structure or line structure.
- Keep the output in one canonical span model instead of source-specific tag handling leaking outward.

What "done" should mean:
- USFX and OSIS preserve red-letter spans reliably.
- Zefania preserves them where the source style conventions clearly encode them.

#### E. Finish poetry, quote, and line structure
What still needs to happen:
- Preserve quote nesting and quote level more consistently.
- Preserve stanza breaks, line starts, and indentation cues more fully.
- Preserve more non-verse poetry blocks instead of collapsing them into generic paragraph blocks.
- Distinguish prose paragraphs from poetic lines more consistently.

What "done" should mean:
- Psalms, prophetic poetry, sayings, and beatitude-style content no longer flatten into generic prose when the source provides line structure.
- The app can tell the difference between prose, poetry, and quoted line groups from parser data alone.

#### F. Finish paragraph and break handling
What still needs to happen:
- Preserve more paragraph starts, paragraph breaks, blank lines, and minor break markers.
- Make `beforeVerse` placement more consistent across supported formats.
- Reduce cases where layout markers are retained only as generic paragraph blocks without enough meaning.

What "done" should mean:
- Document mode can follow source paragraph flow with less UI-side guessing.
- Paragraph-like layout survives consistently in USFX, OSIS, and Zefania.

#### G. Finish introductions and front matter
What still needs to happen:
- Preserve more Bible-level front matter, not only book-level content.
- Preserve prefaces, introductions, titles, section labels, and table-of-contents labels more completely.
- Distinguish Bible-level front matter from book-level introduction content.
- Keep stronger source metadata so the app can render these sections differently later.

What "done" should mean:
- Preface and introduction content is no longer dropped for the common source structures used by the supported files.
- The shared model can represent Bible-level and book-level front matter separately.

#### H. Finish section and non-verse layout blocks
What still needs to happen:
- Preserve more section markers beyond the current title/head/list/break coverage.
- Capture more metadata from section-like containers where the source uses nested layout tags.
- Reduce cases where meaningful source structure is mapped into one generic heading or paragraph block.

What "done" should mean:
- More non-verse layout survives parsing as distinct structured blocks.
- The reader can render more source structure without heuristics based on plain text.

#### I. Finish word-level metadata
What still needs to happen:
- Preserve Strong's or similar word metadata more reliably.
- Keep the metadata attached to the exact inline span or token it belongs to.
- Avoid dropping metadata when the word also participates in other styling like red-letter or additions.

What "done" should mean:
- Word-level metadata survives in a structured way suitable for future study features.

#### J. Finish translator additions and semantic formatting
What still needs to happen:
- Preserve additions, italics-like semantic additions, and related formatting as structured span kinds.
- Avoid collapsing all non-normal styling into plain text.
- Keep enough metadata so the app can render additions differently if desired.

What "done" should mean:
- Translator-added words and similar source semantics survive consistently in the span model.

#### K. Reduce format lossiness overall
What still needs to happen:
- Review the real source files for USFX, OSIS, and Zefania and identify remaining dropped tags.
- Add focused regression tests for each meaningful structure that is currently lost.
- Decide which remaining source tags should map to existing canonical concepts and which need new shared model support.

What "done" should mean:
- Parser output is intentionally normalized, not accidentally lossy.
- Remaining unsupported tags are known and documented instead of being silently dropped by default.

### Parser: Recommended remaining implementation order
1. Finish note/reference structure and anchor fidelity.
2. Finish poetry, line, paragraph, and break fidelity.
3. Finish introductions, front matter, and section-layout coverage.
4. Finish word metadata and translator-addition fidelity.
5. Audit remaining dropped tags format by format and add focused tests.

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
