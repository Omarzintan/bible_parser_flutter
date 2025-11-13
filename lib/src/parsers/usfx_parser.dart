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

    Book? currentBook;
    Chapter? currentChapter;
    Verse? currentVerse;
    String currentNote = '';
  bool insideFTag = false;
  bool insideXTag = false;
  // Accumulate reference text while inside an <x> tag
  String currentReference = '';

    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'book') {
            String bookId = event.attributes
        .firstWhere((attr) => attr.name == 'id',
          orElse: () => XmlEventAttribute('', '', XmlAttributeType.DOUBLE_QUOTE))
                .value
                .toLowerCase();

            if (bookId.isEmpty) continue;

            final bookNum = _getBookNum(bookId);
            final bookName = _getBookName(bookId.toUpperCase());

            currentBook = Book(id: bookId, num: bookNum, title: bookName);
          } else if (event.name == 'c' && currentBook != null) {
            String chapterNumStr = event.attributes
        .firstWhere((attr) => attr.name == 'id',
          orElse: () => XmlEventAttribute('', '1', XmlAttributeType.DOUBLE_QUOTE))
                .value;

            final chapterNum = int.tryParse(chapterNumStr) ?? 1;

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
            String verseNumStr = event.attributes
        .firstWhere((attr) => attr.name == 'id',
          orElse: () => XmlEventAttribute('', '1', XmlAttributeType.DOUBLE_QUOTE))
                .value;

            final verseNum = int.tryParse(verseNumStr) ?? 1;

            currentVerse = Verse(
              num: verseNum,
              chapterNum: currentChapter.num,
              text: '',
              bookId: currentBook.id,
            );
          } else if (event.isSelfClosing &&
              event.name == 've' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'f' &&
              currentBook != null &&
              currentVerse != null) {
            insideFTag = true;
          } else if (event.name == 'x' &&
              currentBook != null &&
              currentVerse != null) {
            insideXTag = true;
            currentReference = '';
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'book' && currentBook != null) {
            if (currentChapter != null) currentBook.addChapter(currentChapter);
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
            if (currentVerse != null && currentNote.isNotEmpty) {
              currentVerse.notes.add(currentNote);
              currentNote = '';
            }
            insideFTag = false;
          } else if (event.name == 'x') {
            // End of reference tag – store accumulated reference
            if (currentVerse != null && currentReference.isNotEmpty) {
              currentVerse.references.add(currentReference);
            }
            insideXTag = false;
            currentReference = '';
          }
          } else if (event is XmlTextEvent && currentVerse != null) {
            if (insideFTag) {
              currentNote += event.value;
            } else if (insideXTag) {
              // Accumulate reference text
              currentReference += event.value;
            } else {
            final trimmedText = event.value.trim();
            if (trimmedText.isNotEmpty) {
              String newText;
              if (currentVerse.text.isEmpty) {
                newText = trimmedText;
              } else if (trimmedText.startsWith(RegExp(r'[.,;:!?)]'))) {
                newText = currentVerse.text + trimmedText;
              } else {
                newText = '${currentVerse.text} $trimmedText';
              }

              newText = newText
                  .replaceAll(RegExp(r'\s+([.,;:!?])'), r'\1')
                  .replaceAll(RegExp(r'\(\s+'), '(');

              currentVerse = Verse(
                num: currentVerse.num,
                chapterNum: currentVerse.chapterNum,
                text: newText,
                bookId: currentVerse.bookId,
                notes: currentVerse.notes,
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

    String? currentBookId;
    int? currentChapterNum;
    Verse? currentVerse;
    String currentNote = '';
    bool insideFTag = false;
    bool insideXTag = false;

    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'book') {
            String bookId = event.attributes
        .firstWhere((attr) => attr.name == 'id',
          orElse: () => XmlEventAttribute('', '', XmlAttributeType.DOUBLE_QUOTE))
                .value
                .toLowerCase();

            if (bookId.isEmpty) continue;
            currentBookId = bookId;
          } else if (event.name == 'c' && currentBookId != null) {
            String chapterNumStr = event.attributes
        .firstWhere((attr) => attr.name == 'id',
          orElse: () => XmlEventAttribute('', '1', XmlAttributeType.DOUBLE_QUOTE))
                .value;

            currentChapterNum = int.tryParse(chapterNumStr) ?? 1;
          } else if (event.name == 'v' &&
              currentBookId != null &&
              currentChapterNum != null) {
            String verseNumStr = event.attributes
        .firstWhere((attr) => attr.name == 'id',
          orElse: () => XmlEventAttribute('', '1', XmlAttributeType.DOUBLE_QUOTE))
                .value;

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
            if (currentVerse != null && currentNote.isNotEmpty) {
              currentVerse.notes.add(currentNote);
              currentNote = '';
            }
            insideFTag = false;
          } else if (event.name == 'x') {
            insideXTag = false;
          }
        } else if (event is XmlTextEvent && currentVerse != null) {
          if (insideFTag) {
            currentNote += event.value;
          } else if (insideXTag) {
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
                newText = '${currentVerse.text} $trimmedText';
              }

              newText = newText
                  .replaceAll(RegExp(r'\s+([.,;:!?])'), r'\1')
                  .replaceAll(RegExp(r'\(\s+'), '(');

              currentVerse = Verse(
                num: currentVerse.num,
                chapterNum: currentVerse.chapterNum,
                text: newText,
                bookId: currentVerse.bookId,
                notes: currentVerse.notes,
              );
            }
          }
        }
      }
    } catch (e, stackTrace) {
      throw BibleParserException('Error parsing verses: $e\n$stackTrace');
    }
  }

  int _getBookNum(String bookId) {
    final upperBookId = bookId.toUpperCase();
    final keys = _bookNames.keys.toList();
    final index = keys.indexOf(upperBookId);
    return index >= 0 ? index + 1 : 0;
  }

  String _getBookName(String bookId) {
    return _bookNames[bookId] ?? 'Unknown';
  }

  Stream<XmlEvent> parseEvents(String content) {
    try {
      final events = XmlEventDecoder().convert(content);
      return Stream.fromIterable(events);
    } catch (e) {
      throw ParseError('Failed to parse XML content: $e');
    }
  }
}
