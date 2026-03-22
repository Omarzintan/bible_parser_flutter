import 'chapter.dart';
import 'rich_content.dart';
import 'verse.dart';

/// Represents a book in the Bible.
class Book {
  /// The unique identifier for the book (e.g., 'gen', 'exo').
  final String id;
  
  /// The book number in canonical order.
  final int num;
  
  /// The title of the book.
  final String title;

  /// Optional navigation labels or alternate titles for this book.
  final List<TocLabel> tocLabels;

  /// Optional front matter or introduction blocks for this book.
  final List<DocumentBlock> introductionBlocks;
  
  /// The chapters in this book.
  final List<Chapter> _chapters = [];
  
  /// Creates a new book.
  Book({
    required this.id,
    required this.num,
    required this.title,
    this.tocLabels = const [],
    this.introductionBlocks = const [],
  });
  
  /// Creates a book from a map, typically from database results.
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      num: map['num'] as int,
      title: map['title'] as String,
    );
  }
  
  /// Converts this book to a map representation, typically for database storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'num': num,
      'title': title,
    };
  }
  
  /// Adds a chapter to this book.
  void addChapter(Chapter chapter) {
    if (chapter.bookId != id) {
      throw ArgumentError('Chapter book ID (${chapter.bookId}) does not match book ID ($id)');
    }
    _chapters.add(chapter);
  }
  
  /// Gets all chapters in this book.
  List<Chapter> get chapters => List.unmodifiable(_chapters);
  
  /// Gets a chapter by its number.
  Chapter? getChapter(int chapterNum) {
    try {
      return _chapters.firstWhere((c) => c.num == chapterNum);
    } catch (e) {
      return null;
    }
  }
  
  /// Gets all verses in this book.
  List<Verse> get verses {
    final List<Verse> allVerses = [];
    for (final chapter in _chapters) {
      allVerses.addAll(chapter.verses);
    }
    return allVerses;
  }
  
  /// Gets the number of chapters in this book.
  int get chapterCount => _chapters.length;
  
  /// Gets the number of verses in this book.
  int get verseCount => verses.length;
  
  @override
  String toString() => '$title ($id) - $chapterCount chapters, $verseCount verses';
}
