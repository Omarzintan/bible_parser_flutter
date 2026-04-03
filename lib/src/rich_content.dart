enum VerseSpanKind {
  normal,
  wordsOfJesus,
  translatorAddition,
  quote,
  poetry,
  word,
  divineNameTag, // <nd> in USFX, <divineName> in OSIS — LORD / divine name
  properName,    // <pn> in USFX — proper noun (person, place)
  selah,         // <qs> in USFX — Selah / music cue at end of poetic line
  acrosticHeading, // <qa> in USFX — acrostic heading letter (e.g. Aleph)
  emphasis,        // <em> in USFX — general emphasis (renders italic)
  bold,            // <bd> in USFX — bold text
  italic,          // <it> in USFX — italic text
  foreignLanguage, // <fl> in USFX — foreign language word or phrase
  keyword,         // <k> in USFX — glossary keyword or defined term
}

class VerseSpan {
  final String text;
  final VerseSpanKind kind;
  final Map<String, String> metadata;

  const VerseSpan({
    required this.text,
    this.kind = VerseSpanKind.normal,
    this.metadata = const {},
  });
}

class CrossReference {
  final String label;
  final String? target;
  final String? marker;

  /// Origin-verse reference from `<xo>` (USFX) or `<reference type="source">`
  /// (OSIS). Null when the source does not include an explicit origin tag.
  final String? originRef;

  /// Index of the span that was current when this reference appeared in the
  /// XML stream.  Null when the source position could not be determined.
  final int? spanIndex;

  /// Character offset within the verse text where this reference marker
  /// appears.  Null when the source position could not be determined.
  final int? charOffset;

  const CrossReference({
    required this.label,
    this.target,
    this.marker,
    this.originRef,
    this.spanIndex,
    this.charOffset,
  });
}

class Footnote {
  /// Backwards-compatible merged body text (all non-origin text joined).
  final String text;
  final String? marker;

  /// Origin reference from `<fr>` (e.g. "1:1 "). Same as label; kept for
  /// backwards compatibility — prefer [label] or [bodyText] in new code.
  final String? label;

  /// Main footnote body from `<ft>`. Null when the source does not use
  /// explicit `<ft>` tagging (OSIS, Zefania, plain USFX footnotes).
  final String? bodyText;

  /// Quoted text from `<fq>` / `<fqa>`. Null when not present in source.
  final String? quotedText;

  final List<CrossReference> references;

  /// Index of the span that was current when this footnote appeared in the
  /// XML stream.  Null when the source position could not be determined.
  final int? spanIndex;

  /// Character offset within the verse text where this footnote marker
  /// appears.  Null when the source position could not be determined.
  final int? charOffset;

  const Footnote({
    required this.text,
    this.marker,
    this.label,
    this.bodyText,
    this.quotedText,
    this.references = const [],
    this.spanIndex,
    this.charOffset,
  });
}

enum DocumentBlockKind {
  paragraph,
  preface,
  introduction,
  heading,
  tocLabel,
  poetry,
  table,    // <table> container — text is plain join of all cell content
  tableRow, // <row> — one row; cells stored as tab-joined string in metadata['cells']
}

class DocumentBlock {
  final DocumentBlockKind kind;
  final String text;
  final int? level;
  final Map<String, String> metadata;

  const DocumentBlock({
    required this.kind,
    required this.text,
    this.level,
    this.metadata = const {},
  });
}

class TocLabel {
  final String text;
  final int level;

  const TocLabel({
    required this.text,
    required this.level,
  });
}
