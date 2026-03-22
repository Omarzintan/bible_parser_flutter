import 'dart:async';

import 'package:xml/xml_events.dart';

import 'base_parser.dart';
import '../book.dart';
import '../chapter.dart';
import '../errors.dart';
import '../rich_content.dart';
import '../verse.dart';

/// Parser for the OSIS Bible format.
class OsisParser extends BaseParser {
  /// OSIS book ID to canonical book name mapping.
  static const Map<String, String> _bookNames = {
    'Gen': 'Genesis',
    'Exod': 'Exodus',
    'Lev': 'Leviticus',
    'Num': 'Numbers',
    'Deut': 'Deuteronomy',
    'Josh': 'Joshua',
    'Judg': 'Judges',
    'Ruth': 'Ruth',
    '1Sam': '1 Samuel',
    '2Sam': '2 Samuel',
    '1Kgs': '1 Kings',
    '2Kgs': '2 Kings',
    '1Chr': '1 Chronicles',
    '2Chr': '2 Chronicles',
    'Ezra': 'Ezra',
    'Neh': 'Nehemiah',
    'Esth': 'Esther',
    'Job': 'Job',
    'Ps': 'Psalms',
    'Prov': 'Proverbs',
    'Eccl': 'Ecclesiastes',
    'Song': 'Song of Solomon',
    'Isa': 'Isaiah',
    'Jer': 'Jeremiah',
    'Lam': 'Lamentations',
    'Ezek': 'Ezekiel',
    'Dan': 'Daniel',
    'Hos': 'Hosea',
    'Joel': 'Joel',
    'Amos': 'Amos',
    'Obad': 'Obadiah',
    'Jonah': 'Jonah',
    'Mic': 'Micah',
    'Nah': 'Nahum',
    'Hab': 'Habakkuk',
    'Zeph': 'Zephaniah',
    'Hag': 'Haggai',
    'Zech': 'Zechariah',
    'Mal': 'Malachi',
    'Matt': 'Matthew',
    'Mark': 'Mark',
    'Luke': 'Luke',
    'John': 'John',
    'Acts': 'Acts',
    'Rom': 'Romans',
    '1Cor': '1 Corinthians',
    '2Cor': '2 Corinthians',
    'Gal': 'Galatians',
    'Eph': 'Ephesians',
    'Phil': 'Philippians',
    'Col': 'Colossians',
    '1Thess': '1 Thessalonians',
    '2Thess': '2 Thessalonians',
    '1Tim': '1 Timothy',
    '2Tim': '2 Timothy',
    'Titus': 'Titus',
    'Phlm': 'Philemon',
    'Heb': 'Hebrews',
    'Jas': 'James',
    '1Pet': '1 Peter',
    '2Pet': '2 Peter',
    '1John': '1 John',
    '2John': '2 John',
    '3John': '3 John',
    'Jude': 'Jude',
    'Rev': 'Revelation',
  };

  /// Creates a new OSIS parser.
  OsisParser(super.source);

  @override
  bool checkFormat(String content) {
    return content.contains('<osis') || content.contains('<osisText');
  }

  @override
  Stream<Book> parseBooks() async* {
    final content = await getContent();

    Book? currentBook;
    Chapter? currentChapter;
    Verse? currentVerse;

    bool insideTitle = false;
    bool insideNote = false;
    bool insideReference = false;

    String currentTitleText = '';
    String? currentTitleType;

    String currentNoteText = '';
    String? currentNoteLabel;
    final List<CrossReference> currentNoteReferences = <CrossReference>[];

    String currentReferenceText = '';
    String? currentReferenceTarget;

    int translatorAdditionDepth = 0;
    int wordsOfJesusDepth = 0;
    final List<int?> quoteLevels = <int?>[];
    final List<bool> jesusQuoteStack = <bool>[];
    Map<String, String>? currentWordMetadata;

    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (_isBookStart(event)) {
            final osisID = _attributeValue(event, 'osisID');
            if (osisID == null || osisID.isEmpty) continue;

            final bookId = osisID.toLowerCase();
            currentBook = Book(
              id: bookId,
              num: _getBookNum(bookId),
              title: _getBookName(bookId),
              tocLabels: <TocLabel>[],
              introductionBlocks: <DocumentBlock>[],
            );
          } else if (_isChapterStart(event) && currentBook != null) {
            final chapterNum = _readChapterNumber(event);

            if (currentChapter != null && chapterNum != currentChapter.num) {
              currentBook.addChapter(currentChapter);
            }

            currentChapter = Chapter(
              num: chapterNum,
              bookId: currentBook.id,
              blocks: <DocumentBlock>[],
            );
          } else if (_isVerseStart(event) &&
              currentBook != null &&
              currentChapter != null) {
            currentVerse = _createVerse(
              verseNum: _readVerseNumber(event),
              chapterNum: currentChapter.num,
              bookId: currentBook.id,
            );
          } else if (_isChapterEndMarker(event) &&
              currentBook != null &&
              currentChapter != null) {
            currentBook.addChapter(currentChapter);
            currentChapter = null;
          } else if (_isVerseEndMarker(event) &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'title' && currentBook != null) {
            insideTitle = true;
            currentTitleText = '';
            currentTitleType = _attributeValue(event, 'type');
          } else if (event.name == 'note' && currentVerse != null) {
            insideNote = true;
            currentNoteText = '';
            currentNoteLabel =
                _attributeValue(event, 'n') ?? _attributeValue(event, 'type');
            currentNoteReferences.clear();
          } else if (event.name == 'reference' && currentVerse != null) {
            insideReference = true;
            currentReferenceText = '';
            currentReferenceTarget = _attributeValue(event, 'osisRef') ??
                _attributeValue(event, 'target');
          } else if (event.name == 'q' && currentVerse != null) {
            final quoteLevel =
                int.tryParse(_attributeValue(event, 'level') ?? '');
            final isJesusQuote =
                (_attributeValue(event, 'who') ?? '').contains('Jesus');
            quoteLevels.add(quoteLevel);
            jesusQuoteStack.add(isJesusQuote);
            if (isJesusQuote) {
              wordsOfJesusDepth++;
            }
          } else if (event.name == 'transChange' && currentVerse != null) {
            translatorAdditionDepth++;
          } else if (event.name == 'w' && currentVerse != null) {
            currentWordMetadata = _wordMetadataFromEvent(event);
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'div' && currentBook != null) {
            if (currentChapter != null) {
              currentBook.addChapter(currentChapter);
            }
            yield currentBook;
            currentBook = null;
            currentChapter = null;
            currentVerse = null;
          } else if (event.name == 'chapter' &&
              currentBook != null &&
              currentChapter != null) {
            currentBook.addChapter(currentChapter);
            currentChapter = null;
          } else if (event.name == 'verse' &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'title' && currentBook != null) {
            final titleText = currentTitleText.trim();
            if (titleText.isNotEmpty) {
              // OSIS titles can be book front matter or chapter headings.
              // Normalize them into shared document structures instead of
              // leaking raw OSIS tags into the app layer.
              if (currentChapter == null) {
                currentBook.tocLabels.add(
                  TocLabel(
                      text: titleText, level: currentBook.tocLabels.length + 1),
                );
                currentBook.introductionBlocks.add(
                  DocumentBlock(
                    kind: _titleBlockKind(currentTitleType),
                    text: titleText,
                  ),
                );
              } else {
                currentChapter.blocks.add(
                  DocumentBlock(
                    kind: DocumentBlockKind.heading,
                    text: titleText,
                  ),
                );
              }
            }
            insideTitle = false;
            currentTitleText = '';
            currentTitleType = null;
          } else if (event.name == 'note') {
            if (currentVerse != null && currentNoteText.isNotEmpty) {
              currentVerse.notes.add(currentNoteText);
              currentVerse.footnotes.add(
                Footnote(
                  text: currentNoteText,
                  label: currentNoteLabel,
                  references: List<CrossReference>.from(currentNoteReferences),
                ),
              );
            }
            insideNote = false;
            currentNoteText = '';
            currentNoteLabel = null;
            currentNoteReferences.clear();
          } else if (event.name == 'reference') {
            if (currentVerse != null && currentReferenceText.isNotEmpty) {
              final crossReference = CrossReference(
                label: currentReferenceText,
                target: currentReferenceTarget,
              );
              if (insideNote) {
                currentNoteReferences.add(crossReference);
              } else {
                currentVerse.references.add(currentReferenceText);
                currentVerse.crossReferences.add(crossReference);
              }
            }
            insideReference = false;
            currentReferenceText = '';
            currentReferenceTarget = null;
          } else if (event.name == 'q' && quoteLevels.isNotEmpty) {
            final wasJesusQuote = jesusQuoteStack.removeLast();
            quoteLevels.removeLast();
            if (wasJesusQuote && wordsOfJesusDepth > 0) {
              wordsOfJesusDepth--;
            }
          } else if (event.name == 'transChange' &&
              translatorAdditionDepth > 0) {
            translatorAdditionDepth--;
          } else if (event.name == 'w') {
            currentWordMetadata = null;
          }
        } else if (event is XmlTextEvent) {
          final cleaned = _normalizeInlineText(event.value);
          if (cleaned.isEmpty) continue;

          if (insideTitle) {
            currentTitleText = _appendText(currentTitleText, cleaned);
          } else if (insideReference) {
            currentReferenceText = _appendText(currentReferenceText, cleaned);
          } else if (insideNote) {
            currentNoteText = _appendText(currentNoteText, cleaned);
          } else if (currentVerse != null) {
            currentVerse = _appendVerseText(
              currentVerse,
              cleaned,
              kind: _currentSpanKind(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                quoteLevels: quoteLevels,
                wordMetadata: currentWordMetadata,
              ),
              metadata: _currentSpanMetadata(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                quoteLevels: quoteLevels,
                wordMetadata: currentWordMetadata,
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      throw BibleParserException('Error in parseBooks: $e\n$stackTrace');
    }
  }

  @override
  Stream<Verse> parseVerses() async* {
    final content = await getContent();

    String? currentBookId;
    int? currentChapterNum;
    Verse? currentVerse;

    bool insideNote = false;
    bool insideReference = false;

    String currentNoteText = '';
    String? currentNoteLabel;
    final List<CrossReference> currentNoteReferences = <CrossReference>[];

    String currentReferenceText = '';
    String? currentReferenceTarget;

    int translatorAdditionDepth = 0;
    int wordsOfJesusDepth = 0;
    final List<int?> quoteLevels = <int?>[];
    final List<bool> jesusQuoteStack = <bool>[];
    Map<String, String>? currentWordMetadata;

    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (_isBookStart(event)) {
            final osisID = _attributeValue(event, 'osisID');
            if (osisID != null && osisID.isNotEmpty) {
              currentBookId = osisID.toLowerCase();
            }
          } else if (_isChapterStart(event) && currentBookId != null) {
            currentChapterNum = _readChapterNumber(event);
          } else if (_isVerseStart(event) &&
              currentBookId != null &&
              currentChapterNum != null) {
            currentVerse = _createVerse(
              verseNum: _readVerseNumber(event),
              chapterNum: currentChapterNum,
              bookId: currentBookId,
            );
          } else if (_isVerseEndMarker(event) && currentVerse != null) {
            yield currentVerse;
            currentVerse = null;
          } else if (event.name == 'note' && currentVerse != null) {
            insideNote = true;
            currentNoteText = '';
            currentNoteLabel =
                _attributeValue(event, 'n') ?? _attributeValue(event, 'type');
            currentNoteReferences.clear();
          } else if (event.name == 'reference' && currentVerse != null) {
            insideReference = true;
            currentReferenceText = '';
            currentReferenceTarget = _attributeValue(event, 'osisRef') ??
                _attributeValue(event, 'target');
          } else if (event.name == 'q' && currentVerse != null) {
            final quoteLevel =
                int.tryParse(_attributeValue(event, 'level') ?? '');
            final isJesusQuote =
                (_attributeValue(event, 'who') ?? '').contains('Jesus');
            quoteLevels.add(quoteLevel);
            jesusQuoteStack.add(isJesusQuote);
            if (isJesusQuote) {
              wordsOfJesusDepth++;
            }
          } else if (event.name == 'transChange' && currentVerse != null) {
            translatorAdditionDepth++;
          } else if (event.name == 'w' && currentVerse != null) {
            currentWordMetadata = _wordMetadataFromEvent(event);
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'verse' && currentVerse != null) {
            yield currentVerse;
            currentVerse = null;
          } else if (event.name == 'note') {
            if (currentVerse != null && currentNoteText.isNotEmpty) {
              currentVerse.notes.add(currentNoteText);
              currentVerse.footnotes.add(
                Footnote(
                  text: currentNoteText,
                  label: currentNoteLabel,
                  references: List<CrossReference>.from(currentNoteReferences),
                ),
              );
            }
            insideNote = false;
            currentNoteText = '';
            currentNoteLabel = null;
            currentNoteReferences.clear();
          } else if (event.name == 'reference') {
            if (currentVerse != null && currentReferenceText.isNotEmpty) {
              final crossReference = CrossReference(
                label: currentReferenceText,
                target: currentReferenceTarget,
              );
              if (insideNote) {
                currentNoteReferences.add(crossReference);
              } else {
                currentVerse.references.add(currentReferenceText);
                currentVerse.crossReferences.add(crossReference);
              }
            }
            insideReference = false;
            currentReferenceText = '';
            currentReferenceTarget = null;
          } else if (event.name == 'q' && quoteLevels.isNotEmpty) {
            final wasJesusQuote = jesusQuoteStack.removeLast();
            quoteLevels.removeLast();
            if (wasJesusQuote && wordsOfJesusDepth > 0) {
              wordsOfJesusDepth--;
            }
          } else if (event.name == 'transChange' &&
              translatorAdditionDepth > 0) {
            translatorAdditionDepth--;
          } else if (event.name == 'w') {
            currentWordMetadata = null;
          }
        } else if (event is XmlTextEvent && currentVerse != null) {
          final cleaned = _normalizeInlineText(event.value);
          if (cleaned.isEmpty) continue;

          if (insideReference) {
            currentReferenceText = _appendText(currentReferenceText, cleaned);
          } else if (insideNote) {
            currentNoteText = _appendText(currentNoteText, cleaned);
          } else {
            currentVerse = _appendVerseText(
              currentVerse,
              cleaned,
              kind: _currentSpanKind(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                quoteLevels: quoteLevels,
                wordMetadata: currentWordMetadata,
              ),
              metadata: _currentSpanMetadata(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                quoteLevels: quoteLevels,
                wordMetadata: currentWordMetadata,
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      throw BibleParserException('Error parsing verses: $e\n$stackTrace');
    }
  }

  int _getBookNum(String bookId) {
    final keys = _bookNames.keys.toList();
    for (int i = 0; i < keys.length; i++) {
      if (bookId.toLowerCase().startsWith(keys[i].toLowerCase())) {
        return i + 1;
      }
    }
    return 0;
  }

  String _getBookName(String bookId) {
    for (final entry in _bookNames.entries) {
      if (bookId.toLowerCase().startsWith(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return bookId.toUpperCase();
  }

  Stream<XmlEvent> parseEvents(String content) {
    try {
      try {
        final events = XmlEventDecoder().convert(content);
        return Stream.fromIterable(events);
      } catch (_) {
        final cleanedContent =
            content.replaceAll(RegExp(r'xmlns(:\w+)?="[^"]*"'), '');
        final events = XmlEventDecoder().convert(cleanedContent);
        return Stream.fromIterable(events);
      }
    } catch (e, stackTrace) {
      throw ParseError('Failed to parse XML content: $e\n$stackTrace');
    }
  }

  @override
  Future<String> getContent() async {
    try {
      if (source is String) {
        return source as String;
      }

      try {
        return await super.getContent();
      } catch (e) {
        if (source != null) {
          return source.toString();
        }
        rethrow;
      }
    } catch (e) {
      throw ParseError('Failed to read content: $e');
    }
  }

  bool _isBookStart(XmlStartElementEvent event) {
    return event.name == 'div' &&
        event.attributes
            .any((attr) => attr.name == 'type' && attr.value == 'book');
  }

  bool _isChapterStart(XmlStartElementEvent event) {
    return event.name == 'chapter' &&
        !event.attributes.any((attr) => attr.name == 'eID');
  }

  bool _isChapterEndMarker(XmlStartElementEvent event) {
    return event.name == 'chapter' &&
        event.attributes.any((attr) => attr.name == 'eID');
  }

  bool _isVerseStart(XmlStartElementEvent event) {
    return event.name == 'verse' &&
        !event.attributes.any((attr) => attr.name == 'eID');
  }

  bool _isVerseEndMarker(XmlStartElementEvent event) {
    return event.name == 'verse' &&
        event.attributes.any((attr) => attr.name == 'eID');
  }

  int _readChapterNumber(XmlStartElementEvent event) {
    var chapterNumStr = _attributeValue(event, 'n') ??
        _attributeValue(event, 'osisRef') ??
        _attributeValue(event, 'osisID') ??
        '1';

    if (chapterNumStr.contains('.')) {
      chapterNumStr = chapterNumStr.split('.').last;
    }

    return int.tryParse(chapterNumStr) ?? 1;
  }

  int _readVerseNumber(XmlStartElementEvent event) {
    final verseOsisID = _attributeValue(event, 'osisID');
    var verseNumStr = _attributeValue(event, 'n') ?? '1';

    if (verseOsisID != null && verseOsisID.isNotEmpty) {
      final parts = verseOsisID.split('.');
      if (parts.length > 2) {
        verseNumStr = parts[2];
      }
    }

    return int.tryParse(verseNumStr) ?? 1;
  }

  Verse _createVerse({
    required int verseNum,
    required int chapterNum,
    required String bookId,
  }) {
    return Verse(
      num: verseNum,
      chapterNum: chapterNum,
      text: '',
      bookId: bookId,
      notes: <String>[],
      references: <String>[],
      spans: <VerseSpan>[],
      footnotes: <Footnote>[],
      crossReferences: <CrossReference>[],
    );
  }

  Verse _appendVerseText(
    Verse verse,
    String segment, {
    VerseSpanKind kind = VerseSpanKind.normal,
    Map<String, String> metadata = const {},
  }) {
    String newText;
    if (verse.text.isEmpty) {
      newText = segment;
    } else if (segment.startsWith(RegExp(r'[.,;:!?)]'))) {
      newText = verse.text + segment;
    } else {
      newText = '${verse.text} $segment';
    }

    newText = newText
        .replaceAll(RegExp(r'\s+([.,;:!?])'), r'\1')
        .replaceAll(RegExp(r'\(\s+'), '(');

    final spans = List<VerseSpan>.from(verse.spans)
      ..add(
        VerseSpan(
          text: segment,
          kind: kind,
          metadata: metadata,
        ),
      );

    return Verse(
      num: verse.num,
      chapterNum: verse.chapterNum,
      text: newText,
      bookId: verse.bookId,
      notes: verse.notes,
      references: verse.references,
      spans: spans,
      footnotes: verse.footnotes,
      crossReferences: verse.crossReferences,
    );
  }

  VerseSpanKind _currentSpanKind({
    required int wordsOfJesusDepth,
    required int translatorAdditionDepth,
    required List<int?> quoteLevels,
    required Map<String, String>? wordMetadata,
  }) {
    if (wordsOfJesusDepth > 0) return VerseSpanKind.wordsOfJesus;
    if (translatorAdditionDepth > 0) return VerseSpanKind.translatorAddition;
    if (quoteLevels.isNotEmpty) {
      return quoteLevels.any((level) => level != null)
          ? VerseSpanKind.poetry
          : VerseSpanKind.quote;
    }
    if (wordMetadata != null && wordMetadata.isNotEmpty) {
      return VerseSpanKind.word;
    }
    return VerseSpanKind.normal;
  }

  Map<String, String> _currentSpanMetadata({
    required int wordsOfJesusDepth,
    required int translatorAdditionDepth,
    required List<int?> quoteLevels,
    required Map<String, String>? wordMetadata,
  }) {
    final metadata = <String, String>{
      ...?wordMetadata,
    };

    if (wordsOfJesusDepth > 0) {
      metadata['wordsOfJesus'] = 'true';
    }
    if (translatorAdditionDepth > 0) {
      metadata['translatorAddition'] = 'true';
    }
    if (quoteLevels.isNotEmpty && quoteLevels.last != null) {
      metadata['quoteLevel'] = quoteLevels.last.toString();
    }

    return metadata;
  }

  Map<String, String>? _wordMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final lemma = _attributeValue(event, 'lemma');
    if (lemma != null && lemma.isNotEmpty) {
      metadata['lemma'] = lemma;
    }
    final morph = _attributeValue(event, 'morph');
    if (morph != null && morph.isNotEmpty) {
      metadata['morph'] = morph;
    }
    return metadata.isEmpty ? null : metadata;
  }

  DocumentBlockKind _titleBlockKind(String? titleType) {
    switch (titleType) {
      case 'main':
      case 'chapter':
        return DocumentBlockKind.heading;
      case 'sub':
        return DocumentBlockKind.introduction;
      default:
        return DocumentBlockKind.heading;
    }
  }

  String? _attributeValue(XmlStartElementEvent event, String name) {
    for (final attr in event.attributes) {
      if (attr.name == name) {
        return attr.value;
      }
    }
    return null;
  }

  String _normalizeInlineText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _appendText(String current, String next) {
    if (current.isEmpty) return next;
    if (next.startsWith(RegExp(r'[.,;:!?)]'))) {
      return current + next;
    }
    return '$current $next';
  }
}
