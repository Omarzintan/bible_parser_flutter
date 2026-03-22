enum VerseSpanKind {
  normal,
  wordsOfJesus,
  translatorAddition,
  quote,
  poetry,
  word,
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

  const CrossReference({
    required this.label,
    this.target,
    this.marker,
  });
}

class Footnote {
  final String text;
  final String? marker;
  final String? label;
  final List<CrossReference> references;

  const Footnote({
    required this.text,
    this.marker,
    this.label,
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
