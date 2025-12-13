/// Represents a segment of text within a verse with optional styling attributes.
///
/// This class is used to support features like red-letter Bibles (marking Jesus' words)
/// and other text styling based on XML attributes.
class TextSegment {
  /// The text content of this segment.
  final String text;

  /// Optional attributes from XML tags (e.g., speaker, style, type).
  ///
  /// Common attributes:
  /// - `speaker`: Who is speaking (e.g., "Jesus")
  /// - `style`: Text styling (e.g., "italic", "bold")
  /// - `type`: Type of content (e.g., "note", "poetry")
  final Map<String, String>? attributes;

  /// Creates a new text segment.
  TextSegment({
    required this.text,
    this.attributes,
  });

  /// Gets the speaker attribute if present.
  String? get speaker => attributes?['speaker'];

  /// Returns true if this segment is spoken by Jesus.
  bool get isJesus => speaker?.toLowerCase() == 'jesus';

  /// Gets the style attribute if present.
  String? get style => attributes?['style'];

  /// Gets the type attribute if present.
  String? get type => attributes?['type'];

  /// Returns true if this segment is poetry.
  bool get isPoetry => attributes?['poetry'] == 'true';

  /// Creates a text segment from a map, typically from database results.
  factory TextSegment.fromMap(Map<String, dynamic> map) {
    // Parse attributes from JSON string if present
    Map<String, String>? attrs;
    if (map['attributes'] != null && map['attributes'] is String) {
      // Will be implemented when database support is added
      attrs = null; // TODO: Parse JSON string
    }

    return TextSegment(
      text: map['text'] as String,
      attributes: attrs,
    );
  }

  /// Converts this segment to a map representation, typically for database storage.
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'attributes': attributes?.toString(), // TODO: Convert to JSON string
    };
  }

  @override
  String toString() {
    if (attributes != null && attributes!.isNotEmpty) {
      return 'TextSegment(text: "$text", attributes: $attributes)';
    }
    return 'TextSegment(text: "$text")';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TextSegment) return false;

    return text == other.text && _mapsEqual(attributes, other.attributes);
  }

  @override
  int get hashCode => Object.hash(text, attributes);

  /// Helper method to compare maps for equality.
  bool _mapsEqual(Map<String, String>? a, Map<String, String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
