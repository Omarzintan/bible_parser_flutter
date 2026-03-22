import 'dart:async';

import 'package:xml/xml_events.dart';

import 'base_parser.dart';
import '../book.dart';
import '../chapter.dart';
import '../errors.dart';
import '../rich_content.dart';
import '../verse.dart';

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

  UsfxParser(super.source);

  @override
  bool checkFormat(String content) {
    return content.contains('<usfx') || content.contains('<USFX');
  }

  @override
  Stream<Book> parseBooks() async* {
    final content = await getContent();

    Book? currentBook;
    Chapter? currentChapter;
    Verse? currentVerse;

    bool insideFootnote = false;
    bool insideFootnoteLabel = false;
    bool insideCrossReference = false;
    bool insideHeading = false;
    bool insideParagraph = false;
    bool insideChapterParagraph = false;
    bool insideToc = false;
    int wordsOfJesusDepth = 0;
    int translatorAdditionDepth = 0;
    final List<int?> quoteLevels = <int?>[];
    final List<bool> quoteLineStarts = <bool>[];
    Map<String, String>? currentWordMetadata;

    String currentFootnoteText = '';
    String currentFootnoteLabel = '';
    String? currentFootnoteMarker;

    String currentReferenceText = '';
    String? currentReferenceTarget;
    String? currentReferenceMarker;
    List<String> pendingFootnoteMarkers = <String>[];
    List<String> pendingReferenceMarkers = <String>[];
    var nextAnnotationIndex = 0;

    String nextGeneratedMarker() {
      final marker = _generatedMarker(nextAnnotationIndex);
      nextAnnotationIndex++;
      return marker;
    }

    String currentHeadingText = '';
    String currentParagraphText = '';
    String currentChapterParagraphText = '';
    String currentTocText = '';
    String? currentStructuredBlockTag;
    String currentStructuredBlockText = '';
    int? currentTocLevel;
    int? currentStructuredBlockLevel;
    Map<String, String> currentChapterParagraphMetadata = const {};
    DocumentBlock? pendingChapterParagraphBlock;

    try {
      final events = await parseEvents(content).toList();

      for (final event in events) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'book') {
            final bookId = _attributeValue(event, 'id')?.toLowerCase() ?? '';
            if (bookId.isEmpty) continue;

            currentBook = Book(
              id: bookId,
              num: _getBookNum(bookId),
              title: _getBookName(bookId.toUpperCase()),
              tocLabels: <TocLabel>[],
              introductionBlocks: <DocumentBlock>[],
            );
          } else if (event.name == 'c' && currentBook != null) {
            final chapterNum =
                int.tryParse(_attributeValue(event, 'id') ?? '') ?? 1;

            if (currentChapter != null && chapterNum != currentChapter.num) {
              currentBook.addChapter(currentChapter);
              currentChapter = null;
            }

            currentChapter = Chapter(
              num: chapterNum,
              bookId: currentBook.id,
              blocks: <DocumentBlock>[],
            );
          } else if (event.name == 'v' &&
              currentBook != null &&
              currentChapter != null) {
            final verseNum =
                int.tryParse(_attributeValue(event, 'id') ?? '') ?? 1;
            if (pendingChapterParagraphBlock != null) {
              // USFX often uses `<p>` as a marker that the next verse starts a
              // new paragraph. Preserve that boundary instead of forcing the
              // app to guess paragraph breaks later.
              currentChapter.blocks.add(
                DocumentBlock(
                  kind: _paragraphKindFromMetadata(
                    pendingChapterParagraphBlock.metadata,
                  ),
                  text: pendingChapterParagraphBlock.text,
                  metadata: {
                    ...pendingChapterParagraphBlock.metadata,
                    'beforeVerse': verseNum.toString(),
                  },
                ),
              );
              pendingChapterParagraphBlock = null;
            }
            currentVerse = _createVerse(
              verseNum: verseNum,
              chapterNum: currentChapter.num,
              bookId: currentBook.id,
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            nextAnnotationIndex = 0;
          } else if (event.isSelfClosing &&
              event.name == 've' &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'f' && currentVerse != null) {
            insideFootnote = true;
            currentFootnoteText = '';
            currentFootnoteLabel = '';
            currentFootnoteMarker = _attributeValue(event, 'caller');
          } else if (event.name == 'fr' && insideFootnote) {
            insideFootnoteLabel = true;
          } else if (event.name == 'x' && currentVerse != null) {
            insideCrossReference = true;
            currentReferenceText = '';
            currentReferenceTarget = null;
            currentReferenceMarker = _attributeValue(event, 'caller');
          } else if (event.name == 'ref' &&
              (insideFootnote || insideCrossReference)) {
            currentReferenceTarget = _attributeValue(event, 'tgt');
          } else if (event.name == 'toc' && currentBook != null) {
            insideToc = true;
            currentTocText = '';
            currentTocLevel =
                int.tryParse(_attributeValue(event, 'level') ?? '');
          } else if (event.name == 'h' && currentBook != null) {
            insideHeading = true;
            currentHeadingText = '';
          } else if (_isStructuredBlockTag(event.name) &&
              currentBook != null &&
              currentVerse == null) {
            currentStructuredBlockTag = event.name;
            currentStructuredBlockText = '';
            currentStructuredBlockLevel = _structuredBlockLevel(event.name);
          } else if (event.name == 'p' &&
              currentBook != null &&
              currentChapter == null) {
            // Before the first chapter, paragraph content is treated as
            // book/front-matter introduction content instead of verse text.
            insideParagraph = true;
            currentParagraphText = '';
          } else if (event.name == 'p' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse == null) {
            insideChapterParagraph = true;
            currentChapterParagraphText = '';
            currentChapterParagraphMetadata =
                _paragraphMetadataFromEvent(event);
            if (event.isSelfClosing) {
              pendingChapterParagraphBlock = DocumentBlock(
                kind:
                    _paragraphKindFromMetadata(currentChapterParagraphMetadata),
                text: '',
                metadata: currentChapterParagraphMetadata,
              );
              insideChapterParagraph = false;
              currentChapterParagraphText = '';
              currentChapterParagraphMetadata = const {};
            }
          } else if (event.name == 'b' &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse == null) {
            // USFX `<b>` is a source layout break. Preserve it as a block
            // marker instead of dropping it so the reader can decide how to
            // render the break later.
            pendingChapterParagraphBlock = DocumentBlock(
              kind: DocumentBlockKind.paragraph,
              text: '',
              metadata: const {'sourceTag': 'b', 'style': 'b'},
            );
          } else if (event.name == 'wj' && currentVerse != null) {
            wordsOfJesusDepth++;
          } else if (event.name == 'add' && currentVerse != null) {
            translatorAdditionDepth++;
          } else if (event.name == 'q' && currentVerse != null) {
            quoteLevels
                .add(int.tryParse(_attributeValue(event, 'level') ?? ''));
            quoteLineStarts.add(true);
          } else if (event.name == 'w' && currentVerse != null) {
            currentWordMetadata = _wordMetadataFromEvent(event);
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'book' && currentBook != null) {
            if (currentChapter != null) {
              currentBook.addChapter(currentChapter);
            }
            yield currentBook;
            currentBook = null;
            currentChapter = null;
            currentVerse = null;
          } else if (event.name == 'c' &&
              currentBook != null &&
              currentChapter != null) {
            currentBook.addChapter(currentChapter);
            currentChapter = null;
          } else if (event.name == 'v' &&
              currentChapter != null &&
              currentVerse != null) {
            currentChapter.addVerse(currentVerse);
            currentVerse = null;
          } else if (event.name == 'f') {
            if (currentVerse != null && currentFootnoteText.isNotEmpty) {
              final footnoteMarker = _normalizeAnnotationMarker(
                currentFootnoteMarker ?? currentFootnoteLabel,
                nextGeneratedMarker,
              );
              currentVerse.notes.add(currentFootnoteText);
              currentVerse.footnotes.add(
                Footnote(
                  text: currentFootnoteText,
                  marker: footnoteMarker,
                  label: currentFootnoteLabel.isEmpty
                      ? null
                      : currentFootnoteLabel,
                ),
              );
              currentVerse = _attachInlineMarker(
                currentVerse,
                footnoteMarker,
                metadataKey: 'footnoteMarkers',
                pendingMarkers: pendingFootnoteMarkers,
              );
            }
            insideFootnote = false;
            insideFootnoteLabel = false;
            currentFootnoteText = '';
            currentFootnoteLabel = '';
            currentFootnoteMarker = null;
          } else if (event.name == 'fr') {
            insideFootnoteLabel = false;
          } else if (event.name == 'x') {
            if (currentVerse != null && currentReferenceText.isNotEmpty) {
              final referenceMarker = _normalizeAnnotationMarker(
                currentReferenceMarker,
                nextGeneratedMarker,
              );
              currentVerse.references.add(currentReferenceText);
              currentVerse.crossReferences.add(
                CrossReference(
                  label: currentReferenceText,
                  target: currentReferenceTarget,
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
            insideCrossReference = false;
            currentReferenceText = '';
            currentReferenceTarget = null;
            currentReferenceMarker = null;
          } else if (event.name == 'toc' && currentBook != null) {
            final text = currentTocText.trim();
            if (text.isNotEmpty) {
              // Preserve TOC labels so the app can later expose richer
              // navigation names instead of relying on a single title field.
              currentBook.tocLabels.add(
                TocLabel(
                  text: text,
                  level: currentTocLevel ?? 0,
                ),
              );
            }
            insideToc = false;
            currentTocText = '';
            currentTocLevel = null;
          } else if (event.name == 'h' && currentBook != null) {
            final text = currentHeadingText.trim();
            if (text.isNotEmpty) {
              // For now headings are normalized into introduction blocks.
              // This keeps the information without forcing raw USFX tags
              // into the app layer.
              currentBook.introductionBlocks.add(
                DocumentBlock(
                  kind: DocumentBlockKind.heading,
                  text: text,
                ),
              );
            }
            insideHeading = false;
            currentHeadingText = '';
          } else if (currentStructuredBlockTag == event.name &&
              currentBook != null) {
            final text = currentStructuredBlockText.trim();
            if (text.isNotEmpty) {
              final block = DocumentBlock(
                kind: _structuredBlockKind(
                  event.name,
                  isPreface: currentBook.id == 'frt' && currentChapter == null,
                ),
                text: text,
                level: currentStructuredBlockLevel,
                metadata: {
                  'sourceTag': event.name,
                  if (currentStructuredBlockLevel != null)
                    'level': currentStructuredBlockLevel.toString(),
                },
              );

              // These USFX intro/section tags carry layout that was previously
              // dropped. Preserve them as shared blocks so the app can render
              // document structure without needing raw USFX-specific logic.
              if (currentChapter == null) {
                currentBook.introductionBlocks.add(block);
              } else if (currentVerse == null) {
                currentChapter.blocks.add(block);
              }
            }
            currentStructuredBlockTag = null;
            currentStructuredBlockText = '';
            currentStructuredBlockLevel = null;
          } else if (event.name == 'p' &&
              currentBook != null &&
              currentChapter == null) {
            final text = currentParagraphText.trim();
            if (text.isNotEmpty) {
              // `FRT` is commonly used for Bible-level preface/front matter.
              // Other pre-chapter paragraphs are treated as book
              // introductions until we have a more detailed block model.
              currentBook.introductionBlocks.add(
                DocumentBlock(
                  kind: currentBook.id == 'frt'
                      ? DocumentBlockKind.preface
                      : DocumentBlockKind.introduction,
                  text: text,
                ),
              );
            }
            insideParagraph = false;
            currentParagraphText = '';
          } else if (event.name == 'p' &&
              currentBook != null &&
              currentChapter != null &&
              insideChapterParagraph) {
            final text = currentChapterParagraphText.trim();
            pendingChapterParagraphBlock = DocumentBlock(
              kind: _paragraphKindFromMetadata(currentChapterParagraphMetadata),
              text: text,
              metadata: currentChapterParagraphMetadata,
            );
            insideChapterParagraph = false;
            currentChapterParagraphText = '';
            currentChapterParagraphMetadata = const {};
          } else if (event.name == 'wj' && wordsOfJesusDepth > 0) {
            wordsOfJesusDepth--;
          } else if (event.name == 'add' && translatorAdditionDepth > 0) {
            translatorAdditionDepth--;
          } else if (event.name == 'q' && quoteLevels.isNotEmpty) {
            quoteLevels.removeLast();
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts.removeLast();
            }
          } else if (event.name == 'w') {
            currentWordMetadata = null;
          }
        } else if (event is XmlTextEvent) {
          final cleaned = _normalizeInlineText(event.value);
          if (cleaned.isEmpty) continue;

          if (insideFootnote && currentVerse != null) {
            if (insideFootnoteLabel) {
              currentFootnoteLabel = _appendText(currentFootnoteLabel, cleaned);
            } else {
              currentFootnoteText = _appendText(currentFootnoteText, cleaned);
            }
          } else if (insideCrossReference && currentVerse != null) {
            currentReferenceText = _appendText(currentReferenceText, cleaned);
          } else if (insideToc && currentBook != null) {
            currentTocText = _appendText(currentTocText, cleaned);
          } else if (insideHeading && currentBook != null) {
            currentHeadingText = _appendText(currentHeadingText, cleaned);
          } else if (currentStructuredBlockTag != null &&
              currentBook != null &&
              currentVerse == null) {
            currentStructuredBlockText = _appendText(
              currentStructuredBlockText,
              cleaned,
            );
          } else if (insideParagraph &&
              currentBook != null &&
              currentChapter == null) {
            currentParagraphText = _appendText(currentParagraphText, cleaned);
          } else if (insideChapterParagraph &&
              currentBook != null &&
              currentChapter != null &&
              currentVerse == null) {
            currentChapterParagraphText = _appendText(
              currentChapterParagraphText,
              cleaned,
            );
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
      throw BibleParserException('Error parsing books: $e\n$stackTrace');
    }
  }

  @override
  Stream<Verse> parseVerses() async* {
    final content = await getContent();

    String? currentBookId;
    int? currentChapterNum;
    Verse? currentVerse;

    bool insideFootnote = false;
    bool insideFootnoteLabel = false;
    bool insideCrossReference = false;
    int wordsOfJesusDepth = 0;
    int translatorAdditionDepth = 0;
    final List<int?> quoteLevels = <int?>[];
    final List<bool> quoteLineStarts = <bool>[];
    Map<String, String>? currentWordMetadata;

    String currentFootnoteText = '';
    String currentFootnoteLabel = '';
    String? currentFootnoteMarker;

    String currentReferenceText = '';
    String? currentReferenceTarget;
    String? currentReferenceMarker;
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
          if (event.name == 'book') {
            final bookId = _attributeValue(event, 'id')?.toLowerCase() ?? '';
            if (bookId.isEmpty) continue;
            currentBookId = bookId;
          } else if (event.name == 'c' && currentBookId != null) {
            currentChapterNum =
                int.tryParse(_attributeValue(event, 'id') ?? '') ?? 1;
          } else if (event.name == 'v' &&
              currentBookId != null &&
              currentChapterNum != null) {
            final verseNum =
                int.tryParse(_attributeValue(event, 'id') ?? '') ?? 1;
            currentVerse = _createVerse(
              verseNum: verseNum,
              chapterNum: currentChapterNum,
              bookId: currentBookId,
            );
            pendingFootnoteMarkers = <String>[];
            pendingReferenceMarkers = <String>[];
            nextAnnotationIndex = 0;
          } else if (event.isSelfClosing &&
              event.name == 've' &&
              currentVerse != null) {
            yield currentVerse;
            currentVerse = null;
          } else if (event.name == 'f' && currentVerse != null) {
            insideFootnote = true;
            currentFootnoteText = '';
            currentFootnoteLabel = '';
            currentFootnoteMarker = _attributeValue(event, 'caller');
          } else if (event.name == 'fr' && insideFootnote) {
            insideFootnoteLabel = true;
          } else if (event.name == 'x' && currentVerse != null) {
            insideCrossReference = true;
            currentReferenceText = '';
            currentReferenceTarget = null;
            currentReferenceMarker = _attributeValue(event, 'caller');
          } else if (event.name == 'ref' &&
              (insideFootnote || insideCrossReference)) {
            currentReferenceTarget = _attributeValue(event, 'tgt');
          } else if (event.name == 'wj' && currentVerse != null) {
            wordsOfJesusDepth++;
          } else if (event.name == 'add' && currentVerse != null) {
            translatorAdditionDepth++;
          } else if (event.name == 'q' && currentVerse != null) {
            quoteLevels
                .add(int.tryParse(_attributeValue(event, 'level') ?? ''));
            quoteLineStarts.add(true);
          } else if (event.name == 'w' && currentVerse != null) {
            currentWordMetadata = _wordMetadataFromEvent(event);
          }
        } else if (event is XmlEndElementEvent) {
          if (event.name == 'v' && currentVerse != null) {
            yield currentVerse;
            currentVerse = null;
          } else if (event.name == 'f') {
            if (currentVerse != null && currentFootnoteText.isNotEmpty) {
              final footnoteMarker = _normalizeAnnotationMarker(
                currentFootnoteMarker ?? currentFootnoteLabel,
                nextGeneratedMarker,
              );
              currentVerse.notes.add(currentFootnoteText);
              currentVerse.footnotes.add(
                Footnote(
                  text: currentFootnoteText,
                  marker: footnoteMarker,
                  label: currentFootnoteLabel.isEmpty
                      ? null
                      : currentFootnoteLabel,
                ),
              );
              currentVerse = _attachInlineMarker(
                currentVerse,
                footnoteMarker,
                metadataKey: 'footnoteMarkers',
                pendingMarkers: pendingFootnoteMarkers,
              );
            }
            insideFootnote = false;
            insideFootnoteLabel = false;
            currentFootnoteText = '';
            currentFootnoteLabel = '';
            currentFootnoteMarker = null;
          } else if (event.name == 'fr') {
            insideFootnoteLabel = false;
          } else if (event.name == 'x') {
            if (currentVerse != null && currentReferenceText.isNotEmpty) {
              final referenceMarker = _normalizeAnnotationMarker(
                currentReferenceMarker,
                nextGeneratedMarker,
              );
              currentVerse.references.add(currentReferenceText);
              currentVerse.crossReferences.add(
                CrossReference(
                  label: currentReferenceText,
                  target: currentReferenceTarget,
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
            insideCrossReference = false;
            currentReferenceText = '';
            currentReferenceTarget = null;
            currentReferenceMarker = null;
          } else if (event.name == 'wj' && wordsOfJesusDepth > 0) {
            wordsOfJesusDepth--;
          } else if (event.name == 'add' && translatorAdditionDepth > 0) {
            translatorAdditionDepth--;
          } else if (event.name == 'q' && quoteLevels.isNotEmpty) {
            quoteLevels.removeLast();
            if (quoteLineStarts.isNotEmpty) {
              quoteLineStarts.removeLast();
            }
          } else if (event.name == 'w') {
            currentWordMetadata = null;
          }
        } else if (event is XmlTextEvent && currentVerse != null) {
          final cleaned = _normalizeInlineText(event.value);
          if (cleaned.isEmpty) continue;

          if (insideFootnote) {
            if (insideFootnoteLabel) {
              currentFootnoteLabel = _appendText(currentFootnoteLabel, cleaned);
            } else {
              currentFootnoteText = _appendText(currentFootnoteText, cleaned);
            }
          } else if (insideCrossReference) {
            currentReferenceText = _appendText(currentReferenceText, cleaned);
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

    // Keep plain text for compatibility and search, but also retain a span
    // per appended segment so richer formatting can be layered in later.
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
    final strongs = _attributeValue(event, 's');
    if (strongs != null && strongs.isNotEmpty) {
      metadata['strongs'] = strongs;
    }
    final lemma = _attributeValue(event, 'l');
    if (lemma != null && lemma.isNotEmpty) {
      metadata['lemma'] = lemma;
    }
    return metadata.isEmpty ? null : metadata;
  }

  Map<String, String> _paragraphMetadataFromEvent(XmlStartElementEvent event) {
    final metadata = <String, String>{};
    final style =
        _attributeValue(event, 'sfm') ?? _attributeValue(event, 'style');
    if (style != null && style.isNotEmpty) {
      metadata['style'] = style;
    }
    return metadata;
  }

  DocumentBlockKind _paragraphKindFromMetadata(Map<String, String> metadata) {
    final style = metadata['style']?.toLowerCase() ?? '';
    if (style.startsWith('q') || style.startsWith('qr')) {
      return DocumentBlockKind.poetry;
    }
    return DocumentBlockKind.paragraph;
  }

  bool _isStructuredBlockTag(String tagName) {
    return RegExp(
      r'^(imt\d*|mt\d*|mte\d*|is\d*|ipi?|im|imi|iot|io\d*|ie|ms\d*|s\d*|sp|cl|cd|d)$',
      caseSensitive: false,
    ).hasMatch(tagName);
  }

  int? _structuredBlockLevel(String tagName) {
    final match = RegExp(r'(\d+)$').firstMatch(tagName);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  DocumentBlockKind _structuredBlockKind(
    String tagName, {
    required bool isPreface,
  }) {
    final normalized = tagName.toLowerCase();
    if (normalized.startsWith('imt') ||
        normalized == 'ip' ||
        normalized == 'ipi' ||
        normalized == 'im' ||
        normalized == 'imi' ||
        normalized == 'iot' ||
        normalized.startsWith('io') ||
        normalized == 'ie') {
      return isPreface
          ? DocumentBlockKind.preface
          : DocumentBlockKind.introduction;
    }
    if (normalized == 'd') {
      return DocumentBlockKind.poetry;
    }
    return DocumentBlockKind.heading;
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
