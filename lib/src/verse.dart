import 'rich_content.dart';

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

      /// The footnotes for this verse.
      final List<String> notes;

   /// The cross‑references for this verse (e.g., "John 3:16").
   final List<String> references;

   /// Structured spans used for rich inline rendering.
   final List<VerseSpan> spans;

   /// Structured footnotes for this verse.
   final List<Footnote> footnotes;

   /// Structured cross-references for this verse.
   final List<CrossReference> crossReferences;

   /// Creates a new verse.
   Verse({
      required this.num,
      required this.chapterNum,
      required this.text,
      required this.bookId,
      List<String>? notes,
      List<String>? references,
      List<VerseSpan>? spans,
      List<Footnote>? footnotes,
      List<CrossReference>? crossReferences,
   })  : notes = notes ?? [],
        references = references ?? [],
        spans = spans ?? const [],
        footnotes = footnotes ?? const [],
        crossReferences = crossReferences ?? const [];

   /// Creates a verse from a map, typically from database results.
   factory Verse.fromMap(Map<String, dynamic> map) {
      return Verse(
         num: map['verse_num'] as int,
         chapterNum: map['chapter_num'] as int,
         text: map['text'] as String,
         bookId: map['book_id'] as String,
      notes: (map['notes'] as String? ?? '').split(';'),
      references: (map['references'] as String? ?? '').split(';'),
      );
   }

   /// Converts this verse to a map representation, typically for database storage.
   Map<String, dynamic> toMap() {
      return {
         'verse_num': num,
         'chapter_num': chapterNum,
         'text': text,
         'book_id': bookId,
      'notes': notes.join(';'),
      'references': references.join(';'),
      };
   }

   @override
   String toString() => '$bookId $chapterNum:$num - $text';
}
