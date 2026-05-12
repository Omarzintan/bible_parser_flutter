/// Represents a footnote attached to a Bible verse.
///
/// Footnotes are stored alongside their verse and referenced by segments.
/// A [TextSegment] with `attributes['footnote'] == id` marks the position
/// in the verse text where this footnote's marker should appear.
///
/// Example usage:
/// ```dart
/// for (final segment in verse.segments ?? []) {
///   if (segment.isFootnoteMarker) {
///     final fn = verse.footnotes!
///         .firstWhere((f) => f.id == segment.footnoteId);
///     print('${fn.marker} ${fn.content}');
///   }
/// }
/// ```
class Footnote {
  /// The footnote identifier (e.g., "f1", "f2").
  final String id;

  /// The display marker for this footnote (e.g., "¹", "²", "*").
  final String marker;

  /// The full text content of the footnote.
  final String content;

  /// Creates a new footnote.
  Footnote({
    required this.id,
    required this.marker,
    required this.content,
  });

  /// Creates a footnote from a database map.
  factory Footnote.fromMap(Map<String, dynamic> map) {
    return Footnote(
      id: map['footnote_id'] as String,
      marker: map['marker'] as String,
      content: map['content'] as String,
    );
  }

  /// Converts this footnote to a map for database storage.
  Map<String, dynamic> toMap(int verseId) {
    return {
      'verse_id': verseId,
      'footnote_id': id,
      'marker': marker,
      'content': content,
    };
  }

  @override
  String toString() => 'Footnote(id: $id, marker: "$marker", content: "$content")';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Footnote) return false;
    return id == other.id && marker == other.marker && content == other.content;
  }

  @override
  int get hashCode => Object.hash(id, marker, content);
}
