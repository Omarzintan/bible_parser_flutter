# Bible Parser Todo Status

## Goal
Track parser work needed to move from plain-text extraction to a richer Bible-data model that can power a proper Bible app.

Status meanings:
- `done`: implemented and verified in current code
- `partial`: some support exists, but output is incomplete or lossy
- `todo`: not implemented yet

## Current Status

- `partial` Phase 1 shared rich-content model types now exist in code, and USFX/OSIS now populate part of them, but output is still incomplete and Zefania remains mostly plain-text.
- `in_progress` Rich parser work is now active across the main app formats: USFX and OSIS preserve some structured spans/notes/front matter, while Zefania is still the least complete path.

| Feature | USFX | OSIS | Zefania | Notes |
|---|---|---|---|---|
| Book/chapter/verse parsing | done | done | done | Core extraction works in all three parsers. |
| Auto format detection | done | done | done | Detection exists in `BibleParser`. |
| Footnotes | partial | partial | todo | USFX and OSIS now preserve plain strings plus basic structured footnotes, but still do not capture every nested note detail. |
| Cross references | partial | partial | todo | USFX and OSIS now preserve plain strings plus basic structured cross references. |
| Red-letter text | partial | partial | todo | USFX `<wj>` and OSIS `<q who="Jesus">` now produce span flags; Zefania still lacks an implementation. |
| Poetry / quoted line structure | partial | partial | todo | USFX/OSIS `<q>` now map into quote/poetry spans, but paragraph-level block handling is still incomplete. |
| Paragraph boundaries | todo | todo | todo | Paragraph-level structure is flattened. |
| Section headings / titles | partial | partial | todo | USFX and OSIS now preserve some headings/titles as introduction or chapter blocks. |
| Word-level metadata | partial | partial | todo | USFX now preserves `s`/`l`; OSIS preserves `lemma`/`morph` when present. |
| Translator additions | partial | partial | todo | USFX `<add>` and OSIS `<transChange>` now produce translator-addition spans. |
| Inline formatting spans | partial | partial | todo | Canonical span output exists for some semantics, but broader style coverage is still not modeled. |
| Introductions / front matter | partial | partial | todo | USFX preserves basic toc labels/headings/pre-chapter blocks; OSIS now preserves some titles and chapter headings. |
| Structured notes model | partial | partial | todo | Structured note/reference objects now exist in USFX and OSIS, but still coexist with legacy plain-text lists and remain lossy. |
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
6. Upgrade Zefania after the shared model settles, focusing first on note/style/title semantics that can map cleanly into the shared model.
7. Only then decide how much of the richer model should be stored in `BibleRepository` and app-side databases.

## App Integration Impact
Any parser upgrade here will likely require matching updates in `basic_bible`, especially:
- `basic_bible/lib/src/models/bible_models.dart`
- `basic_bible/lib/src/repositories/app_bible_repository.dart`
- `basic_bible/lib/src/services/app_database.dart`

The current app can now render some rich inline formatting faithfully, but it still needs better UI for front matter and structured notes.
