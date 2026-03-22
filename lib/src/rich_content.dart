enum VerseSpanKind {
  normal,
  wordsOfJesus,
  translatorAddition,
  quote,
  poetry,
  word,
  divineNameTag, // <nd> in USFX, <divineName> in OSIS — LORD / divine name
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

  const CrossReference({
    required this.label,
    this.target,
    this.marker,
    this.originRef,
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

  const Footnote({
    required this.text,
    this.marker,
    this.label,
    this.bodyText,
    this.quotedText,
    this.references = const [],
  });
}

enum DocumentBlockKind {
  paragraph,
  preface,
  introduction,
  heading,
  tocLabel,
  poetry,
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
