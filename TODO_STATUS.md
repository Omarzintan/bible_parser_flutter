# Bible Parser — Todo Status

## Purpose

Track parser work needed to move from plain-text extraction to a richer Bible-data model.

**Status meanings:**

- `done` — implemented and verified in current code
- `partial` — some support exists, but output is incomplete or lossy
- `in_progress` — actively being worked right now
- `next` — highest-value immediate follow-up
- `todo` — valuable but not yet the immediate next task
- `blocked` — cannot move safely without another prerequisite

**Agent rule — required before ending any work session:**

1. Move completed work into `Completed Recently`.
2. Update `Current Status` to reflect what is actually in the code right now.
3. Set `Recommended Next Step` to ONE concrete next task.
4. Trim `Completed Recently` to the last 10 entries — older history lives in `git log`.
5. Remove any `Current Status` line that is no longer true.
6. Update `CONTEXT.md` only if a structural decision changed (new model shape, new parser architecture, fixed caveat). Do not update it for routine task completion.

If you skip this step the next agent will start from stale information.

**Operating rules:**

- Before making parser changes, add the active slice to `Current Status`.
- After finishing, move it to `Completed Recently` immediately — do not leave it in current status.
- Keep `Current Status` short enough to scan in under 30 seconds.
- Keep `Recommended Next Step` to ONE item only — replace it when priorities shift.
- When a parser slice is verified, add or update a focused test before marking done.
- After a verified slice, create a focused commit.

---

## Known Technical Debt

These are structural issues that will slow down future parser work if not addressed.
They are separate from feature backlog — they affect code quality and testability.

| Issue | Severity | Description |
| --- | --- | --- |
| Parser state explosion | High | Each parser's `parseBooks()` has 40+ local state variables. This is hard to test, easy to break, and hard to read. State should be extracted into a dedicated class or set of smaller methods. |
| No test coverage | High | There are no regression tests for any of the three parsers. XML edge cases are brutal to debug without fixtures. Every new parser feature should be verified by a test using a real XML snippet before being marked done. |
| Marker attachment is a heuristic | Medium | Footnote and reference markers are attached to verse text by inserting metadata into "the last span." This breaks when annotations overlap (e.g., red-letter + footnote at the same word). True positional anchoring requires tracking the exact byte or character offset when the caller appears in the XML stream. |
| Metadata type unsafety | Medium | All span and block metadata is stored as `Map<String, String>`. Numeric values like level or depth get string-converted and back. Missing keys throw at runtime with no compile-time warning. |
| Legacy plain-text fallback coexists with structured output | Low | `Verse.notes` and `Verse.references` (plain `List<String>`) still exist alongside the newer `Verse.footnotes` and `Verse.crossReferences`. This dual output complicates both parser logic and consumer code. The plain-text lists should eventually be deprecated and removed. |
| Zefania style inference is fragile | Low | Zefania has no explicit red-letter or translator-addition tags. The parser infers span kinds from `<STYLE type="...">` name patterns. Different source files may use different naming conventions, so this will silently break on new files. |

---

## Recommended Next Step

- `next` Improve poetry fidelity: preserve stanza breaks and `<q who="...">` attribution metadata for non-Jesus speakers across USFX and OSIS.

**Why this first:**

- All inline tag work is now done: USFX `<nd>/<add>/<pn>/<qs>/<qa>/<em>/<bd>/<it>`, OSIS `<divineName>/<transChange>/<hi>`, Zefania `<BR />`.
- Poetry fidelity is the next priority — Psalms and prophetic books flatten to generic spans without stanza structure.

**Definition of done:**

- Stanza breaks (empty `<lg>` lines in OSIS, `<b>` between verse groups in USFX) attach to the following verse with `stanzaBreak: true` metadata.
- `<q who="...">` preserves the `who` attribute in span metadata for non-Jesus speakers.
- At least one fixture test per item passes.

---

## Current Status

- `partial` All three parser formats now populate part of the shared rich-content model, but output is still incomplete and format fidelity is still lossy across the board.
- `in_progress` Remaining gaps: poetry fidelity (stanza breaks, quote attribution), table content, and word metadata completeness.

**Feature coverage summary:**

| Feature | USFX | OSIS | Zefania | Notes |
| --- | --- | --- | --- | --- |
| Book / chapter / verse parsing | done | done | done | Core extraction works in all three formats. |
| Auto format detection | done | done | done | Detection exists in `BibleParser`. |
| Footnotes | partial | partial | partial | Structured `Footnote` objects exist but nested parts like `fr` / `ft` / `fq` are not separated. |
| Cross-references | partial | partial | partial | Structured `CrossReference` objects exist; multiple refs and targets are partially preserved. |
| Red-letter text | partial | partial | partial | USFX `<wj>` and OSIS `<q who="Jesus">` tracked; Zefania infers from style metadata. |
| Poetry / quoted line structure | partial | partial | partial | Line starts and line groups preserved; stanza grouping and quote levels still incomplete. |
| Paragraph boundaries | partial | partial | partial | Chapter paragraph-start markers preserved in block model; not full layout fidelity. |
| Section headings / titles | partial | partial | partial | Heading blocks exist; level and source-tag metadata coverage still incomplete. |
| Word-level metadata | partial | partial | partial | Strong's stored in span metadata map; morphology and lemma dropped. |
| Translator additions | done | done | partial | `<add>` (USFX) and `<transChange type="added">` (OSIS) emit `translatorAddition` spans. Zefania infers from style conventions. |
| Divine name (LORD) | done | done | todo | `<nd>` (USFX) and `<divineName>` (OSIS) emit `divineNameTag` spans. Zefania has no equivalent tag. |
| Proper name | done | todo | todo | `<pn>` (USFX) emits `properName` span. OSIS has no standard equivalent. |
| Selah / music cue | done | todo | todo | `<qs>` (USFX) emits `selah` span. |
| Acrostic heading | done | todo | todo | `<qa>` (USFX) emits `acrosticHeading` span. |
| Inline emphasis/bold/italic | done | done | todo | USFX `<em>/<bd>/<it>` and OSIS `<hi type="bold/italic/emphasis">` all emit matching span kinds. |
| Introductions / front matter | partial | partial | partial | Book-level intro blocks exist in all three; Bible-level front matter still incomplete. |
| Structured notes model | partial | partial | partial | Structured objects coexist with legacy plain-text lists; still lossy. |
| Lossless round-trip | todo | todo | todo | Parser is optimized for reading, not preservation. |
| Shared rich-content model types | done | done | done | `VerseSpan`, `Footnote`, `CrossReference`, `TocLabel`, `DocumentBlock` all exist. |

The full per-tag breakdown is in `README.md` under **Format Feature Support**.

---

## Completed Recently

- `done` Added OSIS `<hi type="bold/italic/emphasis">` support via hiKinds stack. Fixed README: Zefania `<BR />` was already handled. 71 tests pass.
- `done` Added `emphasis`, `bold`, `italic` span kinds for USFX `<em>`, `<bd>`, `<it>`. 69 tests pass.
- `done` Added `properName`, `selah`, `acrosticHeading` span kinds for USFX `<pn>`, `<qs>`, `<qa>`. 66 tests pass.
- `done` Added `divineNameTag` span kind for USFX `<nd>` and OSIS `<divineName>`. 63 tests pass.
- `done` Added `CrossReference.originRef` from USFX `<xo>` and OSIS `<reference type="source">`. Also fixed OSIS cross-reference-only notes being silently dropped. 60 tests pass.
- `done` OSIS and Zefania parsers now populate `Footnote.bodyText` with the full note text so the app's structured rendering path works for all three formats. 58 tests pass.
- `done` USFX footnote parts separated: `Footnote` gains `bodyText` (`<ft>`) and `quotedText` (`<fq>`/`<fqa>`). Legacy `text` unchanged. App model and serializer updated. 58 tests pass.
- `done` Added fixture-based regression tests (`test/parser_fixture_test.dart`) covering basic verse text, footnotes, cross-references, red-letter spans, and section headings for all three formats (14 tests, 57 total pass).
- `done` Added full per-tag format feature support tables to `README.md` for USFX, OSIS, and Zefania, covering every known tag with current support status.
- `done` Preserved top-level Zefania `INFORMATION` metadata as carried front-matter blocks so source title/description no longer disappears.
- `done` Preserved `beforeVerse` metadata on OSIS chapter-level titles so Psalm superscriptions can be positioned reliably.
- `done` Preserved empty OSIS poetry-line markers inside `<lg><l /></lg>` as stanza-break metadata instead of dropping them.
- `done` Classified OSIS `type="x-ms"` paragraph markers as heading-like structural blocks instead of generic prose.
- `done` Preserved more OSIS title metadata (`short`, `canonical`) so title blocks keep source navigation hints.
- `done` Preserved OSIS `<lb />` break markers as structural layout blocks with source-tag metadata.
- `done` Preserved USFX list-style block tags (`li1`, `li2`, `ili1`) as structured blocks with level metadata.
- `done` Preserved OSIS `<list>` / `<item>` content as structured blocks.
- `done` Fixed OSIS nested section `div` handling so inner divs no longer incorrectly close the book.

---

## Remaining Work

### A. Add test coverage (highest priority)

What needs to happen:

- Add a `test/` directory with fixture-based parser tests.
- Cover at minimum: footnotes, cross-references, red-letter text, and section headings for each format.
- Use real or realistic XML snippets as test inputs, not mocked data.
- Add a regression test whenever a new parser feature is added.

What "done" means:

- `flutter test` runs successfully with at least three tests per parser format.
- New parser changes can be verified without manually running the full app.

### B. Finish structured footnotes

What needs to happen:

- Preserve footnote parts as separate fields: `fr` (origin reference), `ft` (body text), `fq` / `fqa` (quoted text).
- Keep nested references inside footnotes structurally.
- Preserve the caller marker position so the app knows where in the verse text the marker belongs.
- Stop relying on `Verse.notes` (plain string list) as the primary output.

What "done" means:

- A verse with multiple footnotes preserves each as a distinct `Footnote` object with separate parts.
- A footnote with a nested reference keeps that reference structurally, not as merged text.
- The parser still exposes a plain-text fallback for compatibility only.

### C. Finish structured cross-references

What needs to happen:

- Preserve every cross-reference target (`tgt="EZK.10.1"`, `osisRef="..."`) when the source provides one.
- Keep multiple references as separate objects, not one flattened string.
- Preserve the visible marker or label tied to the reference.
- Preserve `xo` (origin verse) as a field on the reference object.

What "done" means:

- Each cross-reference survives as its own `CrossReference` object with label, marker, and target.
- Targets like `JHN.1.1` or `EZK.10.1` are preserved reliably across USFX and OSIS.

### D. Improve inline note and reference anchor placement

What needs to happen:

- Track the XML position where a footnote caller or reference marker appears in the verse stream.
- Place the inline marker on the exact span or word boundary the XML specifies, not heuristically on the last span.
- Reduce cases where overlapping semantics (red-letter text + footnote) cause the marker to detach.

What "done" means:

- Inline note and reference letters render beside the correct words consistently enough to stop relying on fallback ordering.

### E. Finish red-letter text support

What needs to happen:

- Preserve words-of-Jesus spans wherever the source marks them in all three formats.
- Avoid losing red-letter boundaries when they overlap with quote structure or line structure.
- Keep output in one canonical `wordsOfJesus` span kind, not leaking source-specific tag names outward.

What "done" means:

- USFX `<wj>` and OSIS `<q who="Jesus">` preserve red-letter spans reliably.
- Zefania preserves them where the source style conventions clearly encode them.

### F. Finish poetry, quote, and line structure

What needs to happen:

- Preserve quote nesting level more consistently (`<q level="...">`, `<l level="...">`).
- Preserve stanza breaks, line starts, and indentation cues more fully.
- Distinguish prose paragraphs from poetic lines — the app should not have to guess from plain text.

What "done" means:

- Psalms, prophetic poetry, beatitudes, and discourse sections no longer flatten into generic prose when the source provides line structure.
- The app can tell the difference between prose, poetry, and quoted line groups from parser data alone.

### G. Finish paragraph and break handling

What needs to happen:

- Preserve more paragraph starts, paragraph breaks, and minor break markers across all three formats.
- Make `beforeVerse` placement consistent — which verse a block attaches to should not vary by format.
- Reduce cases where layout markers survive only as generic paragraph blocks without enough semantic meaning.

What "done" means:

- Document mode in the reader can follow source paragraph flow with less UI-side guessing.
- Paragraph layout survives consistently across USFX, OSIS, and Zefania.

### H. Add missing USFX intro paragraph support

What needs to happen:

- Preserve `<ip>`, `<imt>`, `<is>` intro paragraph tags as book-level introduction blocks.
- Preserve `<io1>` / `<io2>` intro outline entries as structured content.
- Preserve `<cd>` chapter descriptions as chapter-level blocks.

What "done" means:

- Full USFX book introductions (not only `<h>` and `<toc>`) are available as structured blocks.

### I. Add missing inline tag support (divine name, proper names, Selah, emphasis)

What needs to happen:

- Preserve `<nd>` (divine name / LORD) as a distinct span kind instead of merging into plain text.
- Preserve `<pn>` (proper name) as a distinct span kind.
- Preserve `<qs>` (Selah / music cue) as a structured block or span.
- Preserve `<em>`, `<bd>`, `<it>` as inline formatting spans.

What "done" means:

- These semantics survive in the shared model with their own kind values so the app can render them distinctly.

### J. Finish word-level metadata

What needs to happen:

- Preserve Strong's numbers more reliably (`<w s="H7225">` in USFX, `<w lemma="strong:H1">` in OSIS).
- Preserve morphology (`<w m="...">`) and lemma (`<w l="...">`) fields alongside the Strong's number.
- Keep all metadata attached to the exact inline span or word it belongs to.

What "done" means:

- Word-level metadata survives in a structured way suitable for future study features.
- A word that is both red-letter and has a Strong's number retains both attributes without either being dropped.

### K. Finish translator additions and semantic formatting

What needs to happen:

- Preserve `<add>` (USFX) and `<transChange type="added">` (OSIS) as `translatorAddition` spans reliably.
- Preserve other semantic inline formatting as distinct span kinds rather than collapsing to plain text.
- Confirm which Zefania `<STYLE>` type values encode additions in the real source files used by this project.

What "done" means:

- Translator-added words and similar source semantics survive consistently in the span model.

### L. Reduce overall format lossiness

What needs to happen:

- Audit the real USFX, OSIS, and Zefania source files to identify remaining dropped tags.
- Add focused regression tests for each meaningful structure that is currently silently lost.
- Decide which remaining source tags map to existing canonical concepts and which need new shared model support.
- Add OSIS table support (`<table>` / `<row>` / `<cell>`).

What "done" means:

- Parser output is intentionally normalized, not accidentally lossy.
- Remaining unsupported tags are documented, not silently dropped.

### M. Phase 2 canonical model (longer-term)

What needs to happen:

- Replace single-kind `VerseSpan` with composable inline spans that can carry multiple styles at the same time (e.g., a word that is both `wordsOfJesus` and `quote`).
- Replace separate `Footnote` / `CrossReference` shapes with a unified structured annotation model that preserves kind, caller, label, anchor, and nested parts together.
- Expand `DocumentBlock` kinds so more section, poetry-line, stanza-break, list-item, and before-verse layout cases survive as explicit kinds rather than generic paragraphs or headings.

What "done" means:

- Parser-side model types can represent overlapping inline semantics without flattening into one `kind`.
- Structured annotations preserve nested parts and anchor positions.
- More non-verse layout maps into explicit shared block kinds.

---

## Recommended Implementation Order

1. Add test fixtures and basic parser tests (unblocks everything else).
2. Finish footnote and cross-reference structure and anchor fidelity.
3. Finish red-letter text and inline tag support.
4. Finish poetry, line, paragraph, and break fidelity.
5. Finish introductions, front matter, and missing USFX intro paragraphs.
6. Finish word metadata and translator-addition fidelity.
7. Audit remaining dropped tags by format and add regression tests.
8. Phase 2 canonical model after the above is stable.

---

## App Integration Impact

Any parser model change will likely require matching updates in `basic_bible`:

- `lib/src/models/bible_models.dart` — app-side model mirrors parser model
- `lib/src/features/library/data/app_bible_repository.dart` — maps parser output to app models
- `lib/src/services/app_database.dart` — Drift schema and converters

The current app can render some rich inline formatting, but it still needs better UI for front matter and structured notes once the parser preserves them more completely.
