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
| Test coverage is still selective | High | Fixture-based regression tests now exist, but coverage is still thin relative to parser complexity. XML edge cases are brutal to debug without broader fixtures. Every new parser feature should still be verified by a real XML snippet before being marked done. |
| Marker attachment uses span-level granularity | Low | `spanIndex` now tracks which span a footnote/reference appeared at, replacing the old last-span heuristic. Character-level precision within a span is not yet tracked, but span-level anchoring handles the common cases. |
| Metadata type unsafety | Medium | All span and block metadata is stored as `Map<String, String>`. Numeric values like level or depth get string-converted and back. Missing keys throw at runtime with no compile-time warning. |
| Legacy plain-text fallback coexists with structured output | Low | `Verse.notes` and `Verse.references` (plain `List<String>`) still exist alongside the newer `Verse.footnotes` and `Verse.crossReferences`. This dual output complicates both parser logic and consumer code. The plain-text lists should eventually be deprecated and removed. |
| Zefania style inference is fragile | Low | Zefania has no explicit red-letter or translator-addition tags. The parser infers span kinds from `<STYLE type="...">` name patterns. Different source files may use different naming conventions, so this will silently break on new files. |

---

## Recommended Next Step

- `next` Finish structured footnote part separation in OSIS and Zefania: these formats currently put all note text into `bodyText` as a single string, but USFX already separates `bodyText`, `quotedText`, and `label`. Bringing OSIS and Zefania to the same level removes the last major footnote fidelity gap.

**Why this first:**

- Anchor placement is now solved — `spanIndex` tracks the correct span for all three formats.
- Footnote structure is the next parser gap that directly affects the app's structured note rendering quality.

---

## Current Status

- `partial` All three parser formats now populate part of the shared rich-content model, but output is still incomplete and format fidelity is still lossy across the board.
- `in_progress` Remaining parser gaps with the highest immediate value are footnote part separation in OSIS/Zefania and reducing format lossiness across all three parsers.

**Feature coverage summary:**

| Feature | USFX | OSIS | Zefania | Notes |
| --- | --- | --- | --- | --- |
| Book / chapter / verse parsing | done | done | done | Core extraction works in all three formats. |
| Auto format detection | done | done | done | Detection exists in `BibleParser`. |
| Footnotes | partial | partial | partial | Structured `Footnote` objects with `bodyText`, `quotedText`, `originRef`, and `spanIndex` anchor. USFX has part-level separation; OSIS and Zefania populate `bodyText` only. |
| Cross-references | partial | partial | partial | Structured `CrossReference` objects with `spanIndex` anchor; multiple refs and targets partially preserved. |
| Red-letter text | partial | partial | partial | USFX `<wj>` and OSIS `<q who="Jesus">` tracked; Zefania infers from style metadata. |
| Poetry / quoted line structure | partial | partial | partial | Line starts and line groups preserved; stanza grouping and quote levels still incomplete. |
| Paragraph boundaries | partial | partial | partial | Chapter paragraph-start markers preserved in block model; not full layout fidelity. |
| Section headings / titles | partial | partial | partial | Heading blocks exist; level and source-tag metadata coverage still incomplete. |
| Tables | todo | partial | todo | OSIS table containers and rows now survive as `table` / `tableRow` blocks with row/cell metadata; no richer cell model yet. |
| Word-level metadata | done | done | partial | Strong's, lemma, and morphology preserved in span metadata. Zefania has no standard word-level tags. |
| Translator additions | done | done | partial | `<add>` (USFX) and `<transChange type="added">` (OSIS) emit `translatorAddition` spans. Zefania infers from style conventions. |
| Divine name (LORD) | done | done | todo | `<nd>` (USFX) and `<divineName>` (OSIS) emit `divineNameTag` spans. Zefania has no equivalent tag. |
| Proper name | done | n/a | n/a | `<pn>` (USFX) emits `properName` span. OSIS and Zefania have no standard equivalent tag. |
| Selah / music cue | done | n/a | n/a | `<qs>` (USFX) emits `selah` span. OSIS and Zefania encode selah as inline text. |
| Acrostic heading | done | n/a | n/a | `<qa>` (USFX) emits `acrosticHeading` span. OSIS uses `<title type="acrostic">` which maps to heading blocks. |
| Inline emphasis/bold/italic | done | done | todo | USFX `<em>/<bd>/<it>` and OSIS `<hi type="bold/italic/emphasis">` all emit matching span kinds. |
| Introductions / front matter | partial | partial | partial | Book-level intro blocks exist in all three; Bible-level front matter still incomplete. |
| Structured notes model | partial | partial | partial | Structured objects coexist with legacy plain-text lists; still lossy. |
| Lossless round-trip | todo | todo | todo | Parser is optimized for reading, not preservation. |
| Shared rich-content model types | done | done | done | `VerseSpan`, `Footnote`, `CrossReference`, `TocLabel`, `DocumentBlock` all exist. |

The full per-tag breakdown is in `README.md` under **Format Feature Support**.

---

## Completed Recently

- `done` Added `spanIndex` anchor tracking to `Footnote` and `CrossReference` — all three parsers now record the span index where the annotation appeared in the XML stream, replacing the last-span heuristic. Includes fixture test for multi-span anchor placement. 80 tests pass.
- `done` Fixed USFX `<cd>` (chapter description) to classify as `introduction` instead of `heading`, and added fixture test covering `<imt>`, `<ip>`, `<is1>`, `<io1>`, and `<cd>`. 36 fixture tests pass.
- `done` Added USFX morphology (`m` attribute) to word metadata and added fixture tests for word metadata in both USFX and OSIS. 35 fixture tests pass.
- `done` Preserved OSIS `<table>` / `<row>` / `<cell>` as explicit `table` and `tableRow` document blocks with table/row/cell metadata, and added a fixture regression test for it.
- `done` Added USFX `<q who="...">` speaker attribution — all non-empty `who` values now emit `quoteWho` in span metadata. 33 fixture tests pass.
- `done` Added stanza-break metadata (`stanzaBreak: 'true'`) to USFX `<b>` blocks and OSIS empty `<l />` blocks. 33 fixture tests pass.
- `done` Added OSIS `<q who="...">` speaker attribution to span metadata — non-Jesus speakers emit `quoteWho`. 33 fixture tests pass.
- `done` Added OSIS `<hi type="bold/italic/emphasis">` support via hiKinds stack. Fixed README: Zefania `<BR />` was already handled. 33 fixture tests pass.
- `done` Added `emphasis`, `bold`, `italic` span kinds for USFX `<em>`, `<bd>`, `<it>`. 33 fixture tests pass.
- `done` Added `properName`, `selah`, `acrosticHeading` span kinds for USFX `<pn>`, `<qs>`, `<qa>`. 33 fixture tests pass.

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
