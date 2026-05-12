import 'text_segment.dart';
import 'footnote.dart';

/// Represents a verse in the Bible.
class Verse {
  /// The verse number.
  final int num;

  /// The chapter number this verse belongs to.
  final int chapterNum;

  /// The text content of the verse.
  final String text;

  /// The book ID this verse belongs to.
  final String bookId;

  /// Optional list of text segments with styling information.
  ///
  /// This field is populated when the source XML contains styling tags
  /// (e.g., `<q who="Jesus">` for red-letter Bibles). If null, the verse
  /// has no special styling and the [text] field should be used directly.
  ///
  /// Footnote marker positions are encoded as segments with
  /// `attributes['footnote']` set to the corresponding [Footnote.id].
  final List<TextSegment>? segments;

  /// Optional list of footnotes attached to this verse.
  ///
  /// To find where a footnote appears in the verse, look for a [TextSegment]
  /// in [segments] where `segment.isFootnoteMarker == true` and
  /// `segment.footnoteId == footnote.id`.
  final List<Footnote>? footnotes;

  /// Creates a new verse.
  Verse({
    required this.num,
    required this.chapterNum,
    required this.text,
    required this.bookId,
    this.segments,
    this.footnotes,
  });

  /// Returns true if this verse contains words spoken by Jesus.
  ///
  /// This is a convenience getter that checks if any segment has
  /// the speaker attribute set to "Jesus".
  bool get hasJesusWords => segments?.any((s) => s.isJesus) ?? false;

  /// Returns true if this verse contains footnotes.
  bool get hasFootnotes => footnotes != null && footnotes!.isNotEmpty;

  /// Creates a verse from a map, typically from database results.
  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      num: map['verse_num'] as int,
      chapterNum: map['chapter_num'] as int,
      text: map['text'] as String,
      bookId: map['book_id'] as String,
    );
  }

  /// Converts this verse to a map representation, typically for database storage.
  Map<String, dynamic> toMap() {
    return {
      'verse_num': num,
      'chapter_num': chapterNum,
      'text': text,
      'book_id': bookId,
    };
  }

  @override
  String toString() => '$bookId $chapterNum:$num - $text';
}
