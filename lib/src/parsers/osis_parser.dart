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
    bool insideHead = false;
    bool insideSpeaker = false;
    bool insideNote = false;
    bool insideReference = false;
    bool insideParagraph = false;
    bool insideListItem = false;
    bool insideBlockLine = false;
    bool currentBlockLineHasText = false;

    String currentTitleText = '';
    String? currentTitleType;
    Map<String, String> currentTitleMetadata = const {};
    String currentHeadText = '';
    Map<String, String> currentHeadMetadata = const {};
    String currentSpeakerText = '';
    Map<String, String> currentSpeakerMetadata = const {};

    String currentNoteText = '';
    String? currentNoteLabel;
    final List<CrossReference> currentNoteReferences = <CrossReference>[];

    String currentReferenceText = '';
    String? currentReferenceTarget;
    String? currentReferenceMarker;
    String currentParagraphText = '';
    int currentParagraphEmptyLineCount = 0;
    String currentListItemText = '';
    Map<String, String> currentParagraphMetadata = const {};
    Map<String, String> currentListItemMetadata = const {};
    DocumentBlock? pendingParagraphBlock;
    final List<Map<String, String>> listMetadataStack = <Map<String, String>>[];

    int translatorAdditionDepth = 0;
    int wordsOfJesusDepth = 0;
    final List<int?> quoteLevels = <int?>[];
    final List<bool> jesusQuoteStack = <bool>[];
    final List<bool> quoteLineStarts = <bool>[];
    final List<int?> lineLevels = <int?>[];
    final List<Map<String, String>> sectionDivMetadataStack =
        <Map<String, String>>[];
    Map<String, String>? currentWordMetadata;
    List<String> pendingFootnoteMarkers = <String>[];
    List<String> pendingReferenceMarkers = <String>[];
    var nextAnnotationIndex = 0;

    String nextGeneratedMarker() {
      final marker = _generatedMarker(nextAnnotationIndex);
      nextAnnotationIndex++;
      return marker;
    }

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
            sectionDivMetadataStack.clear();
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
            if (pendingParagraphBlock != null) {
              // Preserve chapter paragraph markers before the verse that
              // starts them so the app can render document-driven paragraphs
              // instead of guessing where prose should break.
              currentChapter.blocks.add(
                DocumentBlock(
                  kind: _paragraphKindFromMetadata(
                    pendingParagraphBlock.metadata,
                  ),
                  text: currentParagraphText.trim(),
                  metadata: {
                    ...pendingParagraphBlock.metadata,
                    if (currentParagraphEmptyLineCount > 0)
                      'emptyLineCount':
                          currentParagraphEmptyLineCount.toString(),
                    'beforeVerse': _readVerseNumber(event).toString(),
                  },
                ),
              );
              pendingParagraphBlock = null;
              currentParagraphText = '';
              currentParagraphEmptyLineCount = 0;
            }
            currentVerse = _createVerse(
              verseNum: _readVerseNumber(event),
              chapterNum: currentChapter.num,
              bookId: currentBook.id,
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            nextAnnotationIndex = 0;
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
            currentTitleMetadata = _titleMetadataFromEvent(event);
          } else if (event.name == 'head' &&
              currentBook != null &&
              currentVerse == null) {
            insideHead = true;
            currentHeadText = '';
            currentHeadMetadata = _headMetadataFromEvent(event);
          } else if (event.name == 'speaker' &&
              currentBook != null &&
              currentVerse == null) {
            insideSpeaker = true;
            currentSpeakerText = '';
            currentSpeakerMetadata = _speakerMetadataFromEvent(event);
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
            currentReferenceMarker = _attributeValue(event, 'n');
          } else if (event.name == 'p' &&
              currentBook != null &&
              currentVerse == null) {
            insideParagraph = true;
            currentParagraphText = '';
            currentParagraphEmptyLineCount = 0;
            currentParagraphMetadata = {
              ..._paragraphMetadataFromEvent(event),
              ..._currentSectionMetadata(sectionDivMetadataStack),
              'sourceTag': 'p',
            };
            pendingParagraphBlock = DocumentBlock(
              kind: _paragraphKindFromMetadata(currentParagraphMetadata),
              text: '',
              metadata: currentParagraphMetadata,
            );
          } else if (event.name == 'lg' &&
              currentBook != null &&
              currentVerse == null) {
            insideParagraph = true;
            currentParagraphText = '';
            currentParagraphEmptyLineCount = 0;
            currentParagraphMetadata = {
              ..._paragraphMetadataFromEvent(event),
              ..._currentSectionMetadata(sectionDivMetadataStack),
              'sourceTag': 'lg',
            };
            pendingParagraphBlock = DocumentBlock(
              kind: DocumentBlockKind.poetry,
              text: '',
              metadata: currentParagraphMetadata,
            );
          } else if (event.name == 'lb' &&
              currentBook != null &&
              currentVerse == null) {
            final breakMetadata = {
              ..._currentSectionMetadata(sectionDivMetadataStack),
              'sourceTag': 'lb',
              'style': 'lb',
            };
            if (currentChapter == null) {
              currentBook.introductionBlocks.add(
                DocumentBlock(
                  kind: DocumentBlockKind.paragraph,
                  text: '',
                  metadata: breakMetadata,
                ),
              );
            } else {
              // OSIS line-break markers are source layout cues. Preserve them
              // ahead of the next verse boundary so the reader can choose
              // whether to render them as spacing, line breaks, or section
              // separators later.
              pendingParagraphBlock = DocumentBlock(
                kind: DocumentBlockKind.paragraph,
                text: '',
                metadata: breakMetadata,
              );
            }
          } else if (event.name == 'list' &&
              currentBook != null &&
              currentVerse == null) {
            listMetadataStack.add(_listMetadataFromEvent(event));
          } else if (event.name == 'item' &&
              currentBook != null &&
              currentVerse == null) {
            insideListItem = true;
            currentListItemText = '';
            currentListItemMetadata = {
              ..._currentSectionMetadata(sectionDivMetadataStack),
              ..._currentListMetadata(listMetadataStack),
              ..._itemMetadataFromEvent(event),
              'sourceTag': 'item',
            };
          } else if (event.name == 'div' &&
              currentBook != null &&
              !_isBookStart(event)) {
            // Nested OSIS divs often mark sections inside a book. Track their
            // metadata separately so closing them does not incorrectly end the
            // book, and so inner headings/paragraphs can retain section
            // context for later rendering.
            sectionDivMetadataStack.add(_sectionMetadataFromEvent(event));
          } else if (event.name == 'l' &&
              currentBook != null &&
              currentVerse == null &&
              insideParagraph) {
            insideBlockLine = true;
            currentBlockLineHasText = false;
            if (event.isSelfClosing) {
              currentParagraphEmptyLineCount++;
              insideBlockLine = false;
            }
          } else if (event.name == 'l' && currentVerse != null) {
            lineLevels.add(int.tryParse(_attributeValue(event, 'level') ?? ''));
            quoteLineStarts.add(true);
          } else if (event.name == 'q' && currentVerse != null) {
            final quoteLevel =
                int.tryParse(_attributeValue(event, 'level') ?? '');
            final isJesusQuote =
                (_attributeValue(event, 'who') ?? '').contains('Jesus');
            quoteLevels.add(quoteLevel);
            jesusQuoteStack.add(isJesusQuote);
            quoteLineStarts.add(true);
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
            if (sectionDivMetadataStack.isNotEmpty) {
              sectionDivMetadataStack.removeLast();
            } else {
              if (currentChapter != null) {
                currentBook.addChapter(currentChapter);
              }
              yield currentBook;
              currentBook = null;
              currentChapter = null;
              currentVerse = null;
            }
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
                    metadata: {
                      ..._currentSectionMetadata(sectionDivMetadataStack),
                      ...currentTitleMetadata,
                      'sourceTag': 'title',
                    },
                  ),
                );
              } else {
                currentChapter.blocks.add(
                  DocumentBlock(
                    kind: DocumentBlockKind.heading,
                    text: titleText,
                    metadata: {
                      ..._currentSectionMetadata(sectionDivMetadataStack),
                      ...currentTitleMetadata,
                      'sourceTag': 'title',
                      if (currentVerse == null) 'beforeVerse': '1',
                    },
                  ),
                );
              }
            }
            insideTitle = false;
            currentTitleText = '';
            currentTitleType = null;
            currentTitleMetadata = const {};
          } else if (event.name == 'head' && currentBook != null) {
            final headText = currentHeadText.trim();
            if (headText.isNotEmpty) {
              final block = DocumentBlock(
                kind:
                    _headBlockKind(currentHeadMetadata, currentChapter == null),
                text: headText,
                metadata: {
                  ..._currentSectionMetadata(sectionDivMetadataStack),
                  ...currentHeadMetadata,
                  'sourceTag': 'head',
                },
              );
              if (currentChapter == null) {
                currentBook.introductionBlocks.add(block);
              } else {
                currentChapter.blocks.add(block);
              }
            }
            insideHead = false;
            currentHeadText = '';
            currentHeadMetadata = const {};
          } else if (event.name == 'speaker' && currentBook != null) {
            final speakerText = currentSpeakerText.trim();
            if (speakerText.isNotEmpty) {
              final block = DocumentBlock(
                kind: DocumentBlockKind.heading,
                text: speakerText,
                metadata: {
                  ..._currentSectionMetadata(sectionDivMetadataStack),
                  ...currentSpeakerMetadata,
                  'sourceTag': 'speaker',
                },
              );
              if (currentChapter == null) {
                currentBook.introductionBlocks.add(block);
              } else {
                currentChapter.blocks.add(block);
              }
            }
            insideSpeaker = false;
            currentSpeakerText = '';
            currentSpeakerMetadata = const {};
          } else if (event.name == 'note') {
            if (currentVerse != null && currentNoteText.isNotEmpty) {
              final noteMarker = _normalizeAnnotationMarker(
                currentNoteLabel,
                nextGeneratedMarker,
              );
              currentVerse.notes.add(currentNoteText);
              currentVerse.footnotes.add(
                Footnote(
                  text: currentNoteText,
                  marker: noteMarker,
                  label: currentNoteLabel,
                  references: List<CrossReference>.from(currentNoteReferences),
                ),
              );
              currentVerse = _attachInlineMarker(
                currentVerse,
                noteMarker,
                metadataKey: 'footnoteMarkers',
                pendingMarkers: pendingFootnoteMarkers,
              );
            }
            insideNote = false;
            currentNoteText = '';
            currentNoteLabel = null;
            currentNoteReferences.clear();
          } else if (event.name == 'reference') {
            if (currentVerse != null && currentReferenceText.isNotEmpty) {
              final referenceMarker = _normalizeAnnotationMarker(
                currentReferenceMarker,
                nextGeneratedMarker,
              );
              final crossReference = CrossReference(
                label: currentReferenceText,
                target: currentReferenceTarget,
                marker: referenceMarker,
              );
              if (insideNote) {
                currentNoteReferences.add(crossReference);
              } else {
                currentVerse.references.add(currentReferenceText);
                currentVerse.crossReferences.add(crossReference);
                currentVerse = _attachInlineMarker(
                  currentVerse,
                  referenceMarker,
                  metadataKey: 'referenceMarkers',
                  pendingMarkers: pendingReferenceMarkers,
                );
              }
            }
            insideReference = false;
            currentReferenceText = '';
            currentReferenceTarget = null;
            currentReferenceMarker = null;
          } else if (event.name == 'p' && currentBook != null) {
            if (currentChapter == null && pendingParagraphBlock != null) {
              final introText = currentParagraphText.trim();
              if (introText.isNotEmpty || currentParagraphEmptyLineCount > 0) {
                currentBook.introductionBlocks.add(
                  DocumentBlock(
                    kind: _introBlockKindFromMetadata(
                      pendingParagraphBlock.metadata,
                    ),
                    text: introText,
                    metadata: {
                      ...pendingParagraphBlock.metadata,
                      if (currentParagraphEmptyLineCount > 0)
                        'emptyLineCount':
                            currentParagraphEmptyLineCount.toString(),
                    },
                  ),
                );
              }
              pendingParagraphBlock = null;
              currentParagraphText = '';
              currentParagraphEmptyLineCount = 0;
            }
            insideParagraph = false;
            insideBlockLine = false;
            currentParagraphMetadata = const {};
          } else if (event.name == 'item' && currentBook != null) {
            final itemText = currentListItemText.trim();
            if (insideListItem && itemText.isNotEmpty) {
              final block = DocumentBlock(
                kind: _listItemBlockKind(currentListItemMetadata),
                text: itemText,
                metadata: currentListItemMetadata,
              );
              if (currentChapter == null) {
                currentBook.introductionBlocks.add(block);
              } else {
                currentChapter.blocks.add(block);
              }
            }
            insideListItem = false;
            currentListItemText = '';
            currentListItemMetadata = const {};
          } else if (event.name == 'list' && currentBook != null) {
            if (listMetadataStack.isNotEmpty) {
              listMetadataStack.removeLast();
            }
          } else if (event.name == 'lg' && currentBook != null) {
            if (currentChapter == null && pendingParagraphBlock != null) {
              final introText = currentParagraphText.trim();
              if (introText.isNotEmpty || currentParagraphEmptyLineCount > 0) {
                currentBook.introductionBlocks.add(
                  DocumentBlock(
                    kind: DocumentBlockKind.poetry,
                    text: introText,
                    metadata: {
                      ...pendingParagraphBlock.metadata,
                      if (currentParagraphEmptyLineCount > 0)
                        'emptyLineCount':
                            currentParagraphEmptyLineCount.toString(),
                    },
                  ),
                );
              }
              pendingParagraphBlock = null;
              currentParagraphText = '';
              currentParagraphEmptyLineCount = 0;
            }
            insideParagraph = false;
            insideBlockLine = false;
            currentBlockLineHasText = false;
            currentParagraphMetadata = const {};
          } else if (event.name == 'l' &&
              currentBook != null &&
              currentVerse == null &&
              insideParagraph) {
            if (!currentBlockLineHasText) {
              currentParagraphEmptyLineCount++;
            }
            insideBlockLine = false;
            currentBlockLineHasText = false;
          } else if (event.name == 'l' && currentVerse != null) {
            if (lineLevels.isNotEmpty) {
              lineLevels.removeLast();
            }
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts.removeLast();
            }
          } else if (event.name == 'q' && quoteLevels.isNotEmpty) {
            final wasJesusQuote = jesusQuoteStack.removeLast();
            quoteLevels.removeLast();
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts.removeLast();
            }
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
          } else if (insideHead) {
            currentHeadText = _appendText(currentHeadText, cleaned);
          } else if (insideSpeaker) {
            currentSpeakerText = _appendText(currentSpeakerText, cleaned);
          } else if (insideListItem && currentVerse == null) {
            currentListItemText = _appendText(currentListItemText, cleaned);
          } else if (insideParagraph && currentVerse == null) {
            currentParagraphText = (insideBlockLine && !currentBlockLineHasText)
                ? _appendBlockLineText(currentParagraphText, cleaned)
                : _appendText(currentParagraphText, cleaned);
            currentBlockLineHasText = true;
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
                lineLevels: lineLevels,
                wordMetadata: currentWordMetadata,
              ),
              metadata: _currentSpanMetadata(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                quoteLevels: quoteLevels,
                lineLevels: lineLevels,
                quoteLineStarts: quoteLineStarts,
                wordMetadata: currentWordMetadata,
                pendingFootnoteMarkers: pendingFootnoteMarkers,
                pendingReferenceMarkers: pendingReferenceMarkers,
              ),
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts[quoteLineStarts.length - 1] = false;
            }
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
    String? currentReferenceMarker;

    int translatorAdditionDepth = 0;
    int wordsOfJesusDepth = 0;
    final List<int?> quoteLevels = <int?>[];
    final List<bool> jesusQuoteStack = <bool>[];
    final List<bool> quoteLineStarts = <bool>[];
    final List<int?> lineLevels = <int?>[];
    Map<String, String>? currentWordMetadata;
    List<String> pendingFootnoteMarkers = <String>[];
    List<String> pendingReferenceMarkers = <String>[];
    var nextAnnotationIndex = 0;

    String nextGeneratedMarker() {
      final marker = _generatedMarker(nextAnnotationIndex);
      nextAnnotationIndex++;
      return marker;
    }

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
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            nextAnnotationIndex = 0;
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
            currentReferenceMarker = _attributeValue(event, 'n');
          } else if (event.name == 'l' && currentVerse != null) {
            lineLevels.add(int.tryParse(_attributeValue(event, 'level') ?? ''));
            quoteLineStarts.add(true);
          } else if (event.name == 'q' && currentVerse != null) {
            final quoteLevel =
                int.tryParse(_attributeValue(event, 'level') ?? '');
            final isJesusQuote =
                (_attributeValue(event, 'who') ?? '').contains('Jesus');
            quoteLevels.add(quoteLevel);
            jesusQuoteStack.add(isJesusQuote);
            quoteLineStarts.add(true);
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
              final noteMarker = _normalizeAnnotationMarker(
                currentNoteLabel,
                nextGeneratedMarker,
              );
              currentVerse.notes.add(currentNoteText);
              currentVerse.footnotes.add(
                Footnote(
                  text: currentNoteText,
                  marker: noteMarker,
                  label: currentNoteLabel,
                  references: List<CrossReference>.from(currentNoteReferences),
                ),
              );
              currentVerse = _attachInlineMarker(
                currentVerse,
                noteMarker,
                metadataKey: 'footnoteMarkers',
                pendingMarkers: pendingFootnoteMarkers,
              );
            }
            insideNote = false;
            currentNoteText = '';
            currentNoteLabel = null;
            currentNoteReferences.clear();
          } else if (event.name == 'reference') {
            if (currentVerse != null && currentReferenceText.isNotEmpty) {
              final referenceMarker = _normalizeAnnotationMarker(
                currentReferenceMarker,
                nextGeneratedMarker,
              );
              final crossReference = CrossReference(
                label: currentReferenceText,
                target: currentReferenceTarget,
                marker: referenceMarker,
              );
              if (insideNote) {
                currentNoteReferences.add(crossReference);
              } else {
                currentVerse.references.add(currentReferenceText);
                currentVerse.crossReferences.add(crossReference);
                currentVerse = _attachInlineMarker(
                  currentVerse,
                  referenceMarker,
                  metadataKey: 'referenceMarkers',
                  pendingMarkers: pendingReferenceMarkers,
                );
              }
            }
            insideReference = false;
            currentReferenceText = '';
            currentReferenceTarget = null;
            currentReferenceMarker = null;
          } else if (event.name == 'l' && currentVerse != null) {
            if (lineLevels.isNotEmpty) {
              lineLevels.removeLast();
            }
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts.removeLast();
            }
          } else if (event.name == 'q' && quoteLevels.isNotEmpty) {
            final wasJesusQuote = jesusQuoteStack.removeLast();
            quoteLevels.removeLast();
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts.removeLast();
            }
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
                lineLevels: lineLevels,
                wordMetadata: currentWordMetadata,
              ),
              metadata: _currentSpanMetadata(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                quoteLevels: quoteLevels,
                lineLevels: lineLevels,
                quoteLineStarts: quoteLineStarts,
                wordMetadata: currentWordMetadata,
                pendingFootnoteMarkers: pendingFootnoteMarkers,
                pendingReferenceMarkers: pendingReferenceMarkers,
              ),
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts[quoteLineStarts.length - 1] = false;
            }
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
    required List<int?> lineLevels,
    required Map<String, String>? wordMetadata,
  }) {
    if (wordsOfJesusDepth > 0) return VerseSpanKind.wordsOfJesus;
    if (translatorAdditionDepth > 0) return VerseSpanKind.translatorAddition;
    if (quoteLevels.isNotEmpty || lineLevels.isNotEmpty) {
      return quoteLevels.any((level) => level != null) ||
              lineLevels.any((level) => level != null)
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
    required List<int?> lineLevels,
    required List<bool> quoteLineStarts,
    required Map<String, String>? wordMetadata,
    required List<String> pendingFootnoteMarkers,
    required List<String> pendingReferenceMarkers,
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
    } else if (lineLevels.isNotEmpty && lineLevels.last != null) {
      metadata['quoteLevel'] = lineLevels.last.toString();
    }
    if (quoteLineStarts.isNotEmpty && quoteLineStarts.last) {
      metadata['lineStart'] = 'true';
    }
    if (pendingFootnoteMarkers.isNotEmpty) {
      metadata['footnoteMarkers'] = pendingFootnoteMarkers.join('|');
    }
    if (pendingReferenceMarkers.isNotEmpty) {
      metadata['referenceMarkers'] = pendingReferenceMarkers.join('|');
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

  Map<String, String> _paragraphMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['type'] = type;
    }
    final subType = _attributeValue(event, 'subType');
    if (subType != null && subType.isNotEmpty) {
      metadata['subType'] = subType;
    }
    return metadata;
  }

  Map<String, String> _titleMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['type'] = type;
    }
    final short = _attributeValue(event, 'short');
    if (short != null && short.isNotEmpty) {
      metadata['short'] = short;
    }
    final canonical = _attributeValue(event, 'canonical');
    if (canonical != null && canonical.isNotEmpty) {
      metadata['canonical'] = canonical;
    }
    return metadata;
  }

  Map<String, String> _listMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['listType'] = type;
    }
    final subType = _attributeValue(event, 'subType');
    if (subType != null && subType.isNotEmpty) {
      metadata['listSubType'] = subType;
    }
    return metadata;
  }

  Map<String, String> _itemMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['itemType'] = type;
    }
    final level = _attributeValue(event, 'level');
    if (level != null && level.isNotEmpty) {
      metadata['itemLevel'] = level;
    }
    return metadata;
  }

  Map<String, String> _currentListMetadata(
    List<Map<String, String>> listMetadataStack,
  ) {
    for (final metadata in listMetadataStack.reversed) {
      if (metadata.isNotEmpty) {
        return metadata;
      }
    }
    return const {};
  }

  DocumentBlockKind _paragraphKindFromMetadata(Map<String, String> metadata) {
    final combined =
        '${metadata['type'] ?? ''} ${metadata['subType'] ?? ''}'.toLowerCase();
    if (combined.contains('x-ms') ||
        combined.contains('major-section') ||
        combined.contains('section heading')) {
      return DocumentBlockKind.heading;
    }
    if (combined.contains('quote') ||
        combined.contains('poetry') ||
        combined.contains('line') ||
        combined.contains('lg')) {
      return DocumentBlockKind.poetry;
    }
    return DocumentBlockKind.paragraph;
  }

  DocumentBlockKind _listItemBlockKind(Map<String, String> metadata) {
    final combined =
        '${metadata['listType'] ?? ''} ${metadata['listSubType'] ?? ''} ${metadata['itemType'] ?? ''}'
            .toLowerCase();
    if (combined.contains('poetry') ||
        combined.contains('quote') ||
        combined.contains('line')) {
      return DocumentBlockKind.poetry;
    }
    return DocumentBlockKind.paragraph;
  }

  Map<String, String> _headMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['type'] = type;
    }
    final subType = _attributeValue(event, 'subType');
    if (subType != null && subType.isNotEmpty) {
      metadata['subType'] = subType;
    }
    return metadata;
  }

  Map<String, String> _speakerMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final who = _attributeValue(event, 'who');
    if (who != null && who.isNotEmpty) {
      metadata['who'] = who;
    }
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['type'] = type;
    }
    return metadata;
  }

  Map<String, String> _sectionMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['sectionType'] = type;
    }
    final subType = _attributeValue(event, 'subType');
    if (subType != null && subType.isNotEmpty) {
      metadata['sectionSubType'] = subType;
    }
    final osisId = _attributeValue(event, 'osisID');
    if (osisId != null && osisId.isNotEmpty) {
      metadata['sectionOsisId'] = osisId;
    }
    return metadata;
  }

  Map<String, String> _currentSectionMetadata(
    List<Map<String, String>> sectionDivMetadataStack,
  ) {
    for (final metadata in sectionDivMetadataStack.reversed) {
      if (metadata.isNotEmpty) {
        return metadata;
      }
    }
    return const {};
  }

  DocumentBlockKind _headBlockKind(
    Map<String, String> metadata,
    bool isIntroductionContext,
  ) {
    final combined =
        '${metadata['type'] ?? ''} ${metadata['subType'] ?? ''}'.toLowerCase();
    if (combined.contains('preface')) return DocumentBlockKind.preface;
    if (combined.contains('intro') && isIntroductionContext) {
      return DocumentBlockKind.introduction;
    }
    return DocumentBlockKind.heading;
  }

  DocumentBlockKind _introBlockKindFromMetadata(Map<String, String> metadata) {
    final combined =
        '${metadata['type'] ?? ''} ${metadata['subType'] ?? ''}'.toLowerCase();
    if (combined.contains('preface')) return DocumentBlockKind.preface;
    if (_paragraphKindFromMetadata(metadata) == DocumentBlockKind.heading) {
      return DocumentBlockKind.heading;
    }
    if (_paragraphKindFromMetadata(metadata) == DocumentBlockKind.poetry) {
      return DocumentBlockKind.poetry;
    }
    return DocumentBlockKind.introduction;
  }

  String _generatedMarker(int index) {
    var value = index;
    final buffer = StringBuffer();
    do {
      buffer.writeCharCode('a'.codeUnitAt(0) + (value % 26));
      value = (value ~/ 26) - 1;
    } while (value >= 0);
    return buffer.toString().split('').reversed.join();
  }

  String _normalizeAnnotationMarker(
    String? candidate,
    String Function() fallbackBuilder,
  ) {
    final cleaned = candidate?.trim();
    if (cleaned != null &&
        cleaned.isNotEmpty &&
        RegExp(r'^[A-Za-z0-9]+$').hasMatch(cleaned)) {
      return cleaned.toLowerCase();
    }
    return fallbackBuilder();
  }

  Verse _attachInlineMarker(
    Verse verse,
    String marker, {
    required String metadataKey,
    required List<String> pendingMarkers,
  }) {
    if (verse.spans.isEmpty) {
      pendingMarkers.add(marker);
      return verse;
    }

    final spans = List<VerseSpan>.from(verse.spans);
    final lastSpan = spans.removeLast();
    spans.add(
      VerseSpan(
        text: lastSpan.text,
        kind: lastSpan.kind,
        metadata: _appendMarkerMetadata(lastSpan.metadata, metadataKey, marker),
      ),
    );

    return Verse(
      num: verse.num,
      chapterNum: verse.chapterNum,
      text: verse.text,
      bookId: verse.bookId,
      notes: verse.notes,
      references: verse.references,
      spans: spans,
      footnotes: verse.footnotes,
      crossReferences: verse.crossReferences,
    );
  }

  Map<String, String> _appendMarkerMetadata(
    Map<String, String> metadata,
    String metadataKey,
    String marker,
  ) {
    final markers = (metadata[metadataKey]?.split('|') ?? const <String>[])
        .where((value) => value.isNotEmpty)
        .toList();
    if (!markers.contains(marker)) {
      markers.add(marker);
    }
    return {
      ...metadata,
      metadataKey: markers.join('|'),
    };
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

  String _appendBlockLineText(String current, String next) {
    if (current.isEmpty) return next;
    return '$current\n$next';
  }
}
