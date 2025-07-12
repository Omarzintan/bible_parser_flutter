import 'dart:async';
import 'package:xml/xml_events.dart';

import 'base_parser.dart';
import '../book.dart';
import '../chapter.dart';
import '../verse.dart';
import '../errors.dart';

/// Parser for the USFX Bible format.
class UsfxParser extends BaseParser {
  /// USFX book ID to canonical book name mapping.
  static const Map<String, String> _bookNames = {
    'GEN': 'Genesis',
    'EXO': 'Exodus',
    'LEV': 'Leviticus',
    'NUM': 'Numbers',
    'DEU': 'Deuteronomy',
    'JOS': 'Joshua',
    'JDG': 'Judges',
    'RUT': 'Ruth',
    '1SA': '1 Samuel',
    '2SA': '2 Samuel',
    '1KI': '1 Kings',
    '2KI': '2 Kings',
    '1CH': '1 Chronicles',
    '2CH': '2 Chronicles',
    'EZR': 'Ezra',
    'NEH': 'Nehemiah',
    'EST': 'Esther',
    'JOB': 'Job',
    'PSA': 'Psalms',
    'PRO': 'Proverbs',
    'ECC': 'Ecclesiastes',
    'SNG': 'Song of Solomon',
    'ISA': 'Isaiah',
    'JER': 'Jeremiah',
    'LAM': 'Lamentations',
    'EZK': 'Ezekiel',
    'DAN': 'Daniel',
    'HOS': 'Hosea',
    'JOL': 'Joel',
    'AMO': 'Amos',
    'OBA': 'Obadiah',
    'JON': 'Jonah',
    'MIC': 'Micah',
    'NAM': 'Nahum',
    'HAB': 'Habakkuk',
    'ZEP': 'Zephaniah',
    'HAG': 'Haggai',
    'ZEC': 'Zechariah',
    'MAL': 'Malachi',
    'MAT': 'Matthew',
    'MRK': 'Mark',
    'LUK': 'Luke',
    'JHN': 'John',
    'ACT': 'Acts',
    'ROM': 'Romans',
    '1CO': '1 Corinthians',
    '2CO': '2 Corinthians',
    'GAL': 'Galatians',
    'EPH': 'Ephesians',
    'PHP': 'Philippians',
    'COL': 'Colossians',
    '1TH': '1 Thessalonians',
    '2TH': '2 Thessalonians',
    '1TI': '1 Timothy',
    '2TI': '2 Timothy',
    'TIT': 'Titus',
    'PHM': 'Philemon',
    'HEB': 'Hebrews',
    'JAS': 'James',
    '1PE': '1 Peter',
    '2PE': '2 Peter',
    '1JN': '1 John',
    '2JN': '2 John',
    '3JN': '3 John',
    'JUD': 'Jude',
    'REV': 'Revelation',
  };

  /// Creates a new USFX parser.
  UsfxParser(super.source);

  @override
  bool checkFormat(String content) {
    // Check for USFX format markers
    return content.contains('<usfx') || content.contains('<USFX');
  }

  @override
  Stream<Book> parseBooks() async* {
    final content = await getContent();

    // Current parsing state
    Book? currentBook;
    Chapter? currentChapter;
    Verse? currentVerse;
    // True when we are inside a <f> tag. These tags are used for
    // footnotes. We skip them for now.
    bool insideFTag = false;
    // True when we are inside a <x> tag. These tags are used for
    // cross-references. We skip them for now.
    bool insideXTag = false;

    // Parse XML using events for memory efficiency
    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'book') {
            // Find book ID from attributes
            String bookId = '';

            for (var attr in event.attributes) {
              if (attr.name == 'id') {
                bookId = attr.value.toLowerCase();
                break;
              }
            }

            // Skip if no book ID found
            if (bookId.isEmpty) continue;

            final bookNum = _getBookNum(bookId);
            final bookName = _getBookName(bookId.toUpperCase());

            currentBook = Book(
              id: bookId,
              num: bookNum,
              title: bookName,
            );
          } else if (event.name == 'c' && currentBook != null) {
            // Find chapter number from attributes
            String chapterNumStr = '1';

            for (var attr in event.attributes) {
              if (attr.name == 'id') {
                chapterNumStr = attr.value;
                break;
              }
            }

            final chapterNum = int.tryParse(chapterNumStr) ?? 1;

            // End of Chapter. Note: If chapter number is different from current
            // chapter number, that older chapter has ended. Add current chapter
            // to book
            if (currentChapter != null && chapterNum != currentChapter.num) {
              currentBook.addChapter(currentChapter);
              currentChapter = null;
            }
            currentChapter = Chapter(
              num: chapterNum,
              bookId: currentBook.id,
            );
          } else if (event.name == 'v' &&
              currentBook != null &&
              currentChapter != null) {
            // Find verse number from attributes
            String verseNumStr = '1';

            for (var attr in event.attributes) {
              if (attr.name == 'id') {
                verseNumStr = attr.value;
                break;
              }
            }

            final verseNum = int.tryParse(verseNumStr) ?? 1;

            // Verse text will be collected in the character events
            // This is just setting up the verse
            currentVerse = Verse(
              num: verseNum,
              chapterNum: currentChapter.num,
              text: '',
              bookId: currentBook.id,
            );
          }
          // Closing verses. Some versions use <ve/> instead of </v>
          else if (event.isSelfClosing &&
              event.name == 've' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'f' &&
              currentBook != null &&
              currentVerse != null) {
            // We are inside a footnote tag.
            insideFTag = true;
          } else if (event.name == 'x' &&
              currentBook != null &&
              currentVerse != null) {
            // We are inside a cross-reference tag.
            insideXTag = true;
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'book' && currentBook != null) {
            // Add the last chapter if it exists. Since we don't have end tags for chapters
            // we need to add the last chapter manually
            if (currentChapter != null) {
              currentBook.addChapter(currentChapter);
            }
            yield currentBook;
            currentBook = null;
            currentChapter = null;
          } else if (event.name == 'c' &&
              currentBook != null &&
              currentChapter != null) {
            currentBook.addChapter(currentChapter);
            currentChapter = null;
          } else if (event.name == 'v' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'f') {
            // End of footnote tag
            insideFTag = false;
          } else if (event.name == 'x') {
            // End of cross-reference tag
            insideXTag = false;
          }
        } else if (event is XmlTextEvent && currentVerse != null) {
          if (insideFTag || insideXTag) {
            continue;
          } else {
            final trimmedText = event.value.trim();
            if (trimmedText.isNotEmpty) {
              String newText;
              if (currentVerse.text.isEmpty) {
                newText = trimmedText;
              } else if (trimmedText.startsWith(RegExp(r'[.,;:!?)]'))) {
                newText = currentVerse.text + trimmedText;
              } else {
                newText = currentVerse.text + ' ' + trimmedText;
              }
              // Remove any space before punctuation
              newText = newText.replaceAll(RegExp(r'\s+([.,;:!?])'), r'\1');
              // Remove any space after an opening parenthesis
              newText = newText.replaceAll(RegExp(r'\(\s+'), '(');
              currentVerse = Verse(
                num: currentVerse.num,
                chapterNum: currentVerse.chapterNum,
                text: newText,
                bookId: currentVerse.bookId,
              );
            }
          }
        }
      }
    } catch (e, stackTrace) {
      throw BibleParserException('Error parsing books: $e\n$stackTrace');
    }
  }

  @override
  Stream<Verse> parseVerses() async* {
    final content = await getContent();

    // Current parsing state
    String? currentBookId;
    int? currentChapterNum;
    Verse? currentVerse;
    bool insideFTag = false;
    bool insideXTag = false;

    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'book') {
            String bookId = '';
            for (var attr in event.attributes) {
              if (attr.name == 'id') {
                bookId = attr.value.toLowerCase();
                break;
              }
            }
            if (bookId.isEmpty) continue;
            currentBookId = bookId;
          } else if (event.name == 'c' && currentBookId != null) {
            String chapterNumStr = '1';
            for (var attr in event.attributes) {
              if (attr.name == 'id') {
                chapterNumStr = attr.value;
                break;
              }
            }
            currentChapterNum = int.tryParse(chapterNumStr) ?? 1;
          } else if (event.name == 'v' &&
            currentBookId != null &&
            currentChapterNum != null) {
            String verseNumStr = '1';
          for (var attr in event.attributes) {
            if (attr.name == 'id') {
              verseNumStr = attr.value;
              break;
            }
          }
          final verseNum = int.tryParse(verseNumStr) ?? 1;
          currentVerse = Verse(
            num: verseNum,
            chapterNum: currentChapterNum,
            text: '',
            bookId: currentBookId,
          );
            } else if (event.isSelfClosing &&
              event.name == 've' &&
              currentVerse != null) {
              yield currentVerse;
            currentVerse = null;
              } else if (event.name == 'f' && currentVerse != null) {
                insideFTag = true;
              } else if (event.name == 'x' && currentVerse != null) {
                insideXTag = true;
              }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'v' && currentVerse != null) {
            yield currentVerse;
            currentVerse = null;
          } else if (event.name == 'f') {
            insideFTag = false;
          } else if (event.name == 'x') {
            insideXTag = false;
          }
        } else if (event is XmlTextEvent && currentVerse != null) {
          if (insideFTag || insideXTag) {
            continue;
          } else {
            final trimmedText = event.value.trim();
            if (trimmedText.isNotEmpty) {
              String newText;
              if (currentVerse.text.isEmpty) {
                newText = trimmedText;
              } else if (trimmedText.startsWith(RegExp(r'[.,;:!?)]'))) {
                newText = currentVerse.text + trimmedText;
              } else {
                newText = currentVerse.text + ' ' + trimmedText;
              }
              // Remove any space before punctuation
              newText = newText.replaceAll(RegExp(r'\s+([.,;:!?])'), r'\1');
              // Remove any space after an opening parenthesis
              newText = newText.replaceAll(RegExp(r'\(\s+'), '(');
              currentVerse = Verse(
                num: currentVerse.num,
                chapterNum: currentVerse.chapterNum,
                text: newText,
                bookId: currentVerse.bookId,
              );
            }
          }
        }
      }
    } catch (e, stackTrace) {
      throw BibleParserException('Error parsing verses: $e\n$stackTrace');
    }
  }

  /// Gets the book number based on its ID.
  int _getBookNum(String bookId) {
    final upperBookId = bookId.toUpperCase();
    final keys = _bookNames.keys.toList();
    final index = keys.indexOf(upperBookId);
    return index >= 0 ? index + 1 : 0;
  }

  /// Gets the book name based on its ID.
  String _getBookName(String bookId) {
    return _bookNames[bookId] ?? 'Unknown';
  }

  /// Parses XML events from the content string.
  Stream<XmlEvent> parseEvents(String content) {
    try {
      final events = XmlEventDecoder().convert(content);
      return Stream.fromIterable(events);
    } catch (e) {
      // Handle XML parsing errors
      throw ParseError('Failed to parse XML content: $e');
    }
  }
}
