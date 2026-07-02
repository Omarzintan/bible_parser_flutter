import 'package:equatable/equatable.dart';

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

// NOTE on serialization: the JSON produced by toJson()/consumed by fromJson()
// is persisted inside app SQLite databases (basic_bible). Changing key names
// or enum order is a breaking format change and requires a parser version
// bump in the app.

class VerseSpan extends Equatable {
  final String text;
  final VerseSpanKind kind;
  final Map<String, String> metadata;

  const VerseSpan({
    required this.text,
    this.kind = VerseSpanKind.normal,
    this.metadata = const {},
  });

  factory VerseSpan.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'] as Map<String, dynamic>? ?? const {};
    return VerseSpan(
      text: json['text'] as String,
      kind: VerseSpanKind.values[json['kind'] as int? ?? 0],
      metadata: rawMetadata.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'kind': kind.index, 'metadata': metadata};
  }

  @override
  List<Object?> get props => [text, kind, metadata];
}

class CrossReference extends Equatable {
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

  factory CrossReference.fromJson(Map<String, dynamic> json) {
    return CrossReference(
      label: json['label'] as String,
      target: json['target'] as String?,
      marker: json['marker'] as String?,
      originRef: json['originRef'] as String?,
      spanIndex: json['spanIndex'] as int?,
      charOffset: json['charOffset'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'target': target,
      'marker': marker,
      'originRef': originRef,
      'spanIndex': spanIndex,
      'charOffset': charOffset,
    };
  }

  @override
  List<Object?> get props => [
    label,
    target,
    marker,
    originRef,
    spanIndex,
    charOffset,
  ];
}

class Footnote extends Equatable {
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

  factory Footnote.fromJson(Map<String, dynamic> json) {
    return Footnote(
      text: json['text'] as String,
      marker: json['marker'] as String?,
      label: json['label'] as String?,
      bodyText: json['bodyText'] as String?,
      quotedText: json['quotedText'] as String?,
      references: (json['references'] as List<dynamic>? ?? const [])
          .map((e) => CrossReference.fromJson(e as Map<String, dynamic>))
          .toList(),
      spanIndex: json['spanIndex'] as int?,
      charOffset: json['charOffset'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'marker': marker,
      'label': label,
      'bodyText': bodyText,
      'quotedText': quotedText,
      'references': references.map((e) => e.toJson()).toList(),
      'spanIndex': spanIndex,
      'charOffset': charOffset,
    };
  }

  @override
  List<Object?> get props => [
    text,
    marker,
    label,
    bodyText,
    quotedText,
    references,
    spanIndex,
    charOffset,
  ];
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

class DocumentBlock extends Equatable {
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

  factory DocumentBlock.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'] as Map<String, dynamic>? ?? const {};
    return DocumentBlock(
      kind: DocumentBlockKind.values[json['kind'] as int? ?? 0],
      text: json['text'] as String,
      level: json['level'] as int?,
      metadata: rawMetadata.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.index,
      'text': text,
      'level': level,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [kind, text, level, metadata];
}

class TocLabel extends Equatable {
  final String text;
  final int level;

  const TocLabel({
    required this.text,
    required this.level,
  });

  factory TocLabel.fromJson(Map<String, dynamic> json) {
    return TocLabel(
      text: json['text'] as String,
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'level': level};
  }

  @override
  List<Object?> get props => [text, level];
}
