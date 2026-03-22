import 'rich_content.dart';
import 'verse.dart';

/// Represents a chapter in the Bible.
class Chapter {
  /// The chapter number.
  final int num;
  
  /// The book ID this chapter belongs to.
  final String bookId;
  
  /// The verses in this chapter.
  final List<Verse> _verses = [];

  /// Optional structured blocks that belong to this chapter.
  final List<DocumentBlock> blocks;
  
  /// Creates a new chapter.
  Chapter({
    required this.num,
    required this.bookId,
    this.blocks = const [],
  });
  
  /// Adds a verse to this chapter.
  void addVerse(Verse verse) {
    if (verse.chapterNum != num) {
      throw ArgumentError('Verse chapter number (${verse.chapterNum}) does not match chapter number ($num)');
    }
    if (verse.bookId != bookId) {
      throw ArgumentError('Verse book ID (${verse.bookId}) does not match chapter book ID ($bookId)');
    }
    _verses.add(verse);
  }
  
  /// Gets all verses in this chapter.
  List<Verse> get verses => List.unmodifiable(_verses);
  
  /// Gets a verse by its number.
  Verse? getVerse(int verseNum) {
    try {
      return _verses.firstWhere((v) => v.num == verseNum);
    } catch (e) {
      return null;
    }
  }
  
  /// Gets the number of verses in this chapter.
  int get verseCount => _verses.length;
  
  @override
  String toString() => '$bookId $num ($verseCount verses)';
}
