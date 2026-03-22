import 'dart:async';

import 'package:xml/xml_events.dart';

import 'base_parser.dart';
import '../book.dart';
import '../chapter.dart';
import '../errors.dart';
import '../rich_content.dart';
import '../verse.dart';

/// Parser for the Zefania Bible format.
class ZefaniaParser extends BaseParser {
  /// Zefania book ID to canonical book name mapping.
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

  /// Creates a new Zefania parser.
  ZefaniaParser(super.source);

  @override
  bool checkFormat(String content) {
    return content.contains('<XMLBIBLE') || content.contains('<xmlbible');
  }

  @override
  Stream<Book> parseBooks() async* {
    final content = await getContent();

    Book? currentBook;
    Chapter? currentChapter;
    Verse? currentVerse;

    bool insideProlog = false;
    bool insideCaption = false;
    bool insideNote = false;
    bool insideXref = false;
    bool insideParagraph = false;
    bool insideInformation = false;
    String? currentInformationTag;

    String currentPrologText = '';
    String currentCaptionText = '';
    String currentNoteText = '';
    String? currentNoteLabel;
    String currentXrefText = '';
    String? currentXrefTarget;
    String? currentXrefMarker;
    String currentParagraphText = '';
    String currentInformationText = '';
    Map<String, String> currentPrologMetadata = const {};
    Map<String, String> currentCaptionMetadata = const {};
    Map<String, String> currentParagraphMetadata = const {};
    DocumentBlock? pendingParagraphBlock;
    final List<DocumentBlock> pendingBibleInformationBlocks = <DocumentBlock>[];

    int wordsOfJesusDepth = 0;
    int translatorAdditionDepth = 0;
    final List<BibleStyleContext> styleStack = <BibleStyleContext>[];
    final List<bool> styleLineStarts = <bool>[];
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
          if (event.name == 'BIBLEBOOK') {
            final bookId = _bookIdFromEvent(event);
            if (bookId == null || bookId.isEmpty) continue;

            currentBook = Book(
              id: bookId.toLowerCase(),
              num: _getBookNum(bookId),
              title: _bookTitleFromEvent(event, bookId),
              tocLabels: <TocLabel>[],
              introductionBlocks: <DocumentBlock>[],
            );

            if (pendingBibleInformationBlocks.isNotEmpty) {
              // Zefania places Bible-level metadata before the first book.
              // Until the shared model gets true Bible-level front matter,
              // carry these blocks onto the first book so that metadata does
              // not disappear between parse and render.
              currentBook.introductionBlocks.addAll(
                List<DocumentBlock>.from(pendingBibleInformationBlocks),
              );
              pendingBibleInformationBlocks.clear();
            }

            final bookTitle = _attributeValue(event, 'bname');
            if (bookTitle != null && bookTitle.isNotEmpty) {
              currentBook.tocLabels.add(TocLabel(text: bookTitle, level: 1));
            }
          } else if (event.name == 'INFORMATION') {
            insideInformation = true;
          } else if (insideInformation) {
            currentInformationTag = event.name;
            currentInformationText = '';
          } else if (event.name == 'CHAPTER' && currentBook != null) {
            final chapterNum =
                int.tryParse(_attributeValue(event, 'cnumber') ?? '') ?? 1;
            currentChapter = Chapter(
              num: chapterNum,
              bookId: currentBook.id,
              blocks: <DocumentBlock>[],
            );
          } else if (event.name == 'PROLOG' && currentBook != null) {
            insideProlog = true;
            currentPrologText = '';
            currentPrologMetadata = _blockMetadataFromEvent(
              event,
              sourceTag: 'PROLOG',
            );
          } else if (event.name == 'CAPTION' &&
              currentBook != null &&
              currentChapter != null) {
            insideCaption = true;
            currentCaptionText = '';
            currentCaptionMetadata = _blockMetadataFromEvent(
              event,
              sourceTag: 'CAPTION',
            );
          } else if (event.name == 'VERS' &&
              currentBook != null &&
              currentChapter != null) {
            final verseNum =
                int.tryParse(_attributeValue(event, 'vnumber') ?? '') ?? 1;
            if (pendingParagraphBlock != null) {
              // Zefania paragraph markers are not always rich, but when the
              // source exposes them we preserve the verse boundary so the
              // reader can stay document-driven across formats.
              currentChapter.blocks.add(
                DocumentBlock(
                  kind: pendingParagraphBlock.kind,
                  text: currentParagraphText.trim(),
                  metadata: {
                    ...pendingParagraphBlock.metadata,
                    'beforeVerse': verseNum.toString(),
                  },
                ),
              );
              pendingParagraphBlock = null;
              currentParagraphText = '';
            }
            currentVerse = _createVerse(
              verseNum: verseNum,
              chapterNum: currentChapter.num,
              bookId: currentBook.id,
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            nextAnnotationIndex = 0;
          } else if (event.name == 'NOTE' && currentVerse != null) {
            insideNote = true;
            currentNoteText = '';
            currentNoteLabel =
                _attributeValue(event, 'type') ?? _attributeValue(event, 'n');
          } else if (event.name == 'XREF' && currentVerse != null) {
            insideXref = true;
            currentXrefText = '';
            currentXrefTarget = _attributeValue(event, 'fscope') ??
                _attributeValue(event, 'target');
            currentXrefMarker = _attributeValue(event, 'n');
          } else if (event.name == 'BR' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse == null) {
            insideParagraph = true;
            currentParagraphText = '';
            currentParagraphMetadata = _paragraphMetadataFromEvent(event);
            pendingParagraphBlock = DocumentBlock(
              kind: _paragraphKindFromMetadata(currentParagraphMetadata),
              text: '',
              metadata: currentParagraphMetadata,
            );
            if (event.isSelfClosing) {
              insideParagraph = false;
              currentParagraphMetadata = const {};
            }
          } else if (event.name == 'STYLE' && currentVerse != null) {
            final styleContext = _styleContextFromEvent(event);
            styleStack.add(styleContext);
            styleLineStarts.add(styleContext.kind == VerseSpanKind.poetry);
            if (styleContext.wordsOfJesus) {
              wordsOfJesusDepth++;
            }
            if (styleContext.translatorAddition) {
              translatorAdditionDepth++;
            }
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'BIBLEBOOK' && currentBook != null) {
            yield currentBook;
            currentBook = null;
            currentChapter = null;
            currentVerse = null;
          } else if (event.name == 'INFORMATION') {
            insideInformation = false;
            currentInformationTag = null;
            currentInformationText = '';
          } else if (insideInformation && currentInformationTag == event.name) {
            final text = currentInformationText.trim();
            if (text.isNotEmpty) {
              pendingBibleInformationBlocks.add(
                DocumentBlock(
                  kind: _informationBlockKind(event.name),
                  text: text,
                  metadata: {
                    'sourceTag': event.name,
                    'scope': 'bible',
                  },
                ),
              );
            }
            currentInformationTag = null;
            currentInformationText = '';
          } else if (event.name == 'CHAPTER' &&
              currentBook != null &&
              currentChapter != null) {
            currentBook.addChapter(currentChapter);
            currentChapter = null;
          } else if (event.name == 'PROLOG' && currentBook != null) {
            final text = currentPrologText.trim();
            if (text.isNotEmpty) {
              currentBook.introductionBlocks.add(
                DocumentBlock(
                  kind: DocumentBlockKind.introduction,
                  text: text,
                  metadata: currentPrologMetadata,
                ),
              );
            }
            insideProlog = false;
            currentPrologText = '';
            currentPrologMetadata = const {};
          } else if (event.name == 'CAPTION' &&
              currentBook != null &&
              currentChapter != null) {
            final text = currentCaptionText.trim();
            if (text.isNotEmpty) {
              currentChapter.blocks.add(
                DocumentBlock(
                  kind: DocumentBlockKind.heading,
                  text: text,
                  metadata: currentCaptionMetadata,
                ),
              );
            }
            insideCaption = false;
            currentCaptionText = '';
            currentCaptionMetadata = const {};
          } else if (event.name == 'VERS' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'NOTE') {
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
          } else if (event.name == 'XREF') {
            if (currentVerse != null && currentXrefText.isNotEmpty) {
              final referenceMarker = _normalizeAnnotationMarker(
                currentXrefMarker,
                nextGeneratedMarker,
              );
              currentVerse.references.add(currentXrefText);
              currentVerse.crossReferences.add(
                CrossReference(
                  label: currentXrefText,
                  target: currentXrefTarget,
                  marker: referenceMarker,
                ),
              );
              currentVerse = _attachInlineMarker(
                currentVerse,
                referenceMarker,
                metadataKey: 'referenceMarkers',
                pendingMarkers: pendingReferenceMarkers,
              );
            }
            insideXref = false;
            currentXrefText = '';
            currentXrefTarget = null;
            currentXrefMarker = null;
          } else if (event.name == 'BR') {
            insideParagraph = false;
            currentParagraphMetadata = const {};
          } else if (event.name == 'STYLE' && styleStack.isNotEmpty) {
            final styleContext = styleStack.removeLast();
            if (styleLineStarts.isNotEmpty) {
              styleLineStarts.removeLast();
            }
            if (styleContext.wordsOfJesus && wordsOfJesusDepth > 0) {
              wordsOfJesusDepth--;
            }
            if (styleContext.translatorAddition &&
                translatorAdditionDepth > 0) {
              translatorAdditionDepth--;
            }
          }
        } else if (event is XmlTextEvent) {
          final cleaned = _normalizeInlineText(event.value);
          if (cleaned.isEmpty) continue;

          if (insideInformation && currentInformationTag != null) {
            currentInformationText =
                _appendText(currentInformationText, cleaned);
          } else if (insideProlog && currentBook != null) {
            currentPrologText = _appendText(currentPrologText, cleaned);
          } else if (insideCaption &&
              currentBook != null &&
              currentChapter != null) {
            currentCaptionText = _appendText(currentCaptionText, cleaned);
          } else if (insideNote && currentVerse != null) {
            currentNoteText = _appendText(currentNoteText, cleaned);
          } else if (insideXref && currentVerse != null) {
            currentXrefText = _appendText(currentXrefText, cleaned);
          } else if (insideParagraph &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse == null) {
            currentParagraphText = _appendText(currentParagraphText, cleaned);
          } else if (currentVerse != null) {
            currentVerse = _appendVerseText(
              currentVerse,
              cleaned,
              kind: _currentSpanKind(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                styleStack: styleStack,
              ),
              metadata: _currentSpanMetadata(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                styleStack: styleStack,
                styleLineStarts: styleLineStarts,
                pendingFootnoteMarkers: pendingFootnoteMarkers,
                pendingReferenceMarkers: pendingReferenceMarkers,
              ),
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            if (styleLineStarts.isNotEmpty) {
              styleLineStarts[styleLineStarts.length - 1] = false;
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

    bool insideNote = false;
    bool insideXref = false;

    String currentNoteText = '';
    String? currentNoteLabel;
    String currentXrefText = '';
    String? currentXrefTarget;
    String? currentXrefMarker;

    int wordsOfJesusDepth = 0;
    int translatorAdditionDepth = 0;
    final List<BibleStyleContext> styleStack = <BibleStyleContext>[];
    final List<bool> styleLineStarts = <bool>[];
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
          if (event.name == 'BIBLEBOOK') {
            currentBookId = _bookIdFromEvent(event)?.toLowerCase();
          } else if (event.name == 'CHAPTER' && currentBookId != null) {
            currentChapterNum =
                int.tryParse(_attributeValue(event, 'cnumber') ?? '') ?? 1;
          } else if (event.name == 'VERS' &&
              currentBookId != null &&
              currentChapterNum != null) {
            final verseNum =
                int.tryParse(_attributeValue(event, 'vnumber') ?? '') ?? 1;
            currentVerse = _createVerse(
              verseNum: verseNum,
              chapterNum: currentChapterNum,
              bookId: currentBookId,
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            nextAnnotationIndex = 0;
          } else if (event.name == 'NOTE' && currentVerse != null) {
            insideNote = true;
            currentNoteText = '';
            currentNoteLabel =
                _attributeValue(event, 'type') ?? _attributeValue(event, 'n');
          } else if (event.name == 'XREF' && currentVerse != null) {
            insideXref = true;
            currentXrefText = '';
            currentXrefTarget = _attributeValue(event, 'fscope') ??
                _attributeValue(event, 'target');
            currentXrefMarker = _attributeValue(event, 'n');
          } else if (event.name == 'STYLE' && currentVerse != null) {
            final styleContext = _styleContextFromEvent(event);
            styleStack.add(styleContext);
            styleLineStarts.add(styleContext.kind == VerseSpanKind.poetry);
            if (styleContext.wordsOfJesus) {
              wordsOfJesusDepth++;
            }
            if (styleContext.translatorAddition) {
              translatorAdditionDepth++;
            }
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'VERS' && currentVerse != null) {
            yield currentVerse;
            currentVerse = null;
          } else if (event.name == 'NOTE') {
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
          } else if (event.name == 'XREF') {
            if (currentVerse != null && currentXrefText.isNotEmpty) {
              final referenceMarker = _normalizeAnnotationMarker(
                currentXrefMarker,
                nextGeneratedMarker,
              );
              currentVerse.references.add(currentXrefText);
              currentVerse.crossReferences.add(
                CrossReference(
                  label: currentXrefText,
                  target: currentXrefTarget,
                  marker: referenceMarker,
                ),
              );
              currentVerse = _attachInlineMarker(
                currentVerse,
                referenceMarker,
                metadataKey: 'referenceMarkers',
                pendingMarkers: pendingReferenceMarkers,
              );
            }
            insideXref = false;
            currentXrefText = '';
            currentXrefTarget = null;
            currentXrefMarker = null;
          } else if (event.name == 'STYLE' && styleStack.isNotEmpty) {
            final styleContext = styleStack.removeLast();
            if (styleLineStarts.isNotEmpty) {
              styleLineStarts.removeLast();
            }
            if (styleContext.wordsOfJesus && wordsOfJesusDepth > 0) {
              wordsOfJesusDepth--;
            }
            if (styleContext.translatorAddition &&
                translatorAdditionDepth > 0) {
              translatorAdditionDepth--;
            }
          }
        } else if (event is XmlTextEvent && currentVerse != null) {
          final cleaned = _normalizeInlineText(event.value);
          if (cleaned.isEmpty) continue;

          if (insideNote) {
            currentNoteText = _appendText(currentNoteText, cleaned);
          } else if (insideXref) {
            currentXrefText = _appendText(currentXrefText, cleaned);
          } else {
            currentVerse = _appendVerseText(
              currentVerse,
              cleaned,
              kind: _currentSpanKind(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                styleStack: styleStack,
              ),
              metadata: _currentSpanMetadata(
                wordsOfJesusDepth: wordsOfJesusDepth,
                translatorAdditionDepth: translatorAdditionDepth,
                styleStack: styleStack,
                styleLineStarts: styleLineStarts,
                pendingFootnoteMarkers: pendingFootnoteMarkers,
                pendingReferenceMarkers: pendingReferenceMarkers,
              ),
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            if (styleLineStarts.isNotEmpty) {
              styleLineStarts[styleLineStarts.length - 1] = false;
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
    return 'Unknown';
  }

  Stream<XmlEvent> parseEvents(String content) {
    try {
      final events = XmlEventDecoder().convert(content);
      return Stream.fromIterable(events);
    } catch (e) {
      throw BibleParserException('Error parsing XML: $e');
    }
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

  String? _bookIdFromEvent(XmlStartElementEvent event) {
    return _attributeValue(event, 'bsname') ??
        _attributeValue(event, 'bname') ??
        _attributeValue(event, 'bnumber');
  }

  String _bookTitleFromEvent(
      XmlStartElementEvent event, String fallbackBookId) {
    return _attributeValue(event, 'bname') ?? _getBookName(fallbackBookId);
  }

  Map<String, String> _paragraphMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{'sourceTag': 'BR'};
    final art = _attributeValue(event, 'art');
    if (art != null && art.isNotEmpty) {
      metadata['art'] = art;
    }
    final type = _attributeValue(event, 'type');
    if (type != null && type.isNotEmpty) {
      metadata['type'] = type;
    }
    return metadata;
  }

  DocumentBlockKind _paragraphKindFromMetadata(Map<String, String> metadata) {
    final art = metadata['art']?.toLowerCase() ?? '';
    final type = metadata['type']?.toLowerCase() ?? '';
    if (art.contains('q') ||
        art.contains('poetry') ||
        type.contains('poetry')) {
      return DocumentBlockKind.poetry;
    }
    return DocumentBlockKind.paragraph;
  }

  Map<String, String> _blockMetadataFromEvent(
    XmlStartElementEvent event, {
    required String sourceTag,
  }) {
    final metadata = <String, String>{'sourceTag': sourceTag};
    for (final attribute in event.attributes) {
      if (attribute.value.isNotEmpty) {
        metadata[attribute.name] = attribute.value;
      }
    }
    return metadata;
  }

  DocumentBlockKind _informationBlockKind(String tagName) {
    final normalized = tagName.toLowerCase();
    if (normalized == 'title' || normalized == 'subject') {
      return DocumentBlockKind.heading;
    }
    if (normalized == 'description' || normalized == 'rights') {
      return DocumentBlockKind.preface;
    }
    return DocumentBlockKind.introduction;
  }

  BibleStyleContext _styleContextFromEvent(XmlStartElementEvent event) {
    final styleName = (_attributeValue(event, 'css') ??
            _attributeValue(event, 'id') ??
            _attributeValue(event, 'style') ??
            '')
        .toLowerCase();

    return BibleStyleContext(
      wordsOfJesus: styleName.contains('red') ||
          styleName.contains('jesus') ||
          styleName.contains('wj'),
      translatorAddition:
          styleName.contains('italic') || styleName.contains('add'),
      kind: styleName.contains('poetry') || styleName.contains('quote')
          ? VerseSpanKind.poetry
          : null,
      metadata: {
        if (styleName.isNotEmpty) 'style': styleName,
        if (_attributeValue(event, 'gr') case final gr? when gr.isNotEmpty)
          'gr': gr,
      },
    );
  }

  VerseSpanKind _currentSpanKind({
    required int wordsOfJesusDepth,
    required int translatorAdditionDepth,
    required List<BibleStyleContext> styleStack,
  }) {
    if (wordsOfJesusDepth > 0) return VerseSpanKind.wordsOfJesus;
    if (translatorAdditionDepth > 0) return VerseSpanKind.translatorAddition;

    for (final style in styleStack.reversed) {
      if (style.kind != null) return style.kind!;
    }

    return VerseSpanKind.normal;
  }

  Map<String, String> _currentSpanMetadata({
    required int wordsOfJesusDepth,
    required int translatorAdditionDepth,
    required List<BibleStyleContext> styleStack,
    required List<bool> styleLineStarts,
    required List<String> pendingFootnoteMarkers,
    required List<String> pendingReferenceMarkers,
  }) {
    final metadata = <String, String>{};

    if (wordsOfJesusDepth > 0) {
      metadata['wordsOfJesus'] = 'true';
    }
    if (translatorAdditionDepth > 0) {
      metadata['translatorAddition'] = 'true';
    }

    for (final style in styleStack) {
      metadata.addAll(style.metadata);
    }
    if (styleLineStarts.isNotEmpty && styleLineStarts.last) {
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

  String? _attributeValue(XmlStartElementEvent event, String name) {
    for (final attr in event.attributes) {
      if (attr.name == name) return attr.value;
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
}

class BibleStyleContext {
  final bool wordsOfJesus;
  final bool translatorAddition;
  final VerseSpanKind? kind;
  final Map<String, String> metadata;

  const BibleStyleContext({
    this.wordsOfJesus = false,
    this.translatorAddition = false,
    this.kind,
    this.metadata = const {},
  });
}
