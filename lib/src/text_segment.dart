import 'dart:convert';

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

  /// Gets the transChange attribute if present.
  String? get transChange => attributes?['transChange'];

  /// Returns true if this segment is added text (typically italicized in Bibles).
  bool get isAdded => transChange?.toLowerCase() == 'added';

  /// Returns true if this segment marks a footnote position in the verse.
  bool get isFootnoteMarker => attributes?.containsKey('footnote') ?? false;

  /// Returns the footnote ID this segment references, or null if not a footnote marker.
  String? get footnoteId => attributes?['footnote'];

  /// Creates a text segment from a map, typically from database results.
  factory TextSegment.fromMap(Map<String, dynamic> map) {
    // Parse attributes from JSON string if present
    Map<String, String>? attrs;
    if (map['attributes'] != null && map['attributes'] is String) {
      try {
        final decoded = jsonDecode(map['attributes'] as String);
        if (decoded is Map) {
          attrs = Map<String, String>.from(decoded);
        }
      } catch (e) {
        // If JSON parsing fails, ignore attributes
        attrs = null;
      }
    } else if (map['attributes'] is Map) {
      // Handle case where attributes are already a map
      attrs = Map<String, String>.from(map['attributes'] as Map);
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
      'attributes': attributes != null ? jsonEncode(attributes) : null,
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
  int get hashCode {
    if (attributes == null) {
      return text.hashCode;
    }
    // Compute stable hashCode based on map contents
    int hash = text.hashCode;
    for (final entry in attributes!.entries) {
      hash = Object.hash(hash, entry.key, entry.value);
    }
    return hash;
  }

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
