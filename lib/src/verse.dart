import 'text_segment.dart';

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
  final List<TextSegment>? segments;

  /// Creates a new verse.
  Verse({
    required this.num,
    required this.chapterNum,
    required this.text,
    required this.bookId,
    this.segments,
  });

  /// Returns true if this verse contains words spoken by Jesus.
  ///
  /// This is a convenience getter that checks if any segment has
  /// the speaker attribute set to "Jesus".
  bool get hasJesusWords => segments?.any((s) => s.isJesus) ?? false;

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
