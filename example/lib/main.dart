import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:path/path.dart' as path;

/// Enum for Bible formats supported by the app
enum BibleFormat { osis, usfx, zefania }

void main() {
  runApp(const BibleParserExampleApp());
}

class BibleParserExampleApp extends StatelessWidget {
  const BibleParserExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible Parser Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BibleParserExampleScreen(),
    );
  }
}

class BibleParserExampleScreen extends StatefulWidget {
  const BibleParserExampleScreen({super.key});

  @override
  State<BibleParserExampleScreen> createState() =>
      _BibleParserExampleScreenState();
}

class _BibleParserExampleScreenState extends State<BibleParserExampleScreen> {
  String xmlPath = 'assets/bible_small_osis.xml'; // Default to OSIS format
  BibleFormat currentFormat = BibleFormat.osis;
  bool isLoading = false;
  String result = '';
  BibleRepository? repository;
  bool isFullBible = false;
  bool isUsingSubmodule = false;
  String? selectedSubmoduleFile;

  // For verse viewing feature
  List<Book> books = [];
  Book? selectedBook;
  int? selectedChapter;
  List<int> availableChapters = [];

  // Red-letter display toggle
  bool showRedLetter = true;

  // Italicized text display toggle
  bool showItalics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible Parser Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selection
            Text('Select Bible Format:',
                style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                Radio<BibleFormat>(
                  value: BibleFormat.osis,
                  groupValue: currentFormat,
                  onChanged: (BibleFormat? value) {
                    setState(() {
                      currentFormat = value!;
                      xmlPath = 'assets/bible_small_osis.xml';
                      result = 'Selected OSIS format';
                    });
                  },
                ),
                const Text('OSIS'),
                const SizedBox(width: 20),
                Radio<BibleFormat>(
                  value: BibleFormat.usfx,
                  groupValue: currentFormat,
                  onChanged: (BibleFormat? value) {
                    setState(() {
                      currentFormat = value!;
                      xmlPath = 'assets/bible_small_usfx.xml';
                      result = 'Selected USFX format';
                    });
                  },
                ),
                const Text('USFX'),
              ],
            ),
            const SizedBox(height: 10),
            // Red-letter toggle
            Row(
              children: [
                Switch(
                  value: showRedLetter,
                  onChanged: (value) {
                    setState(() {
                      showRedLetter = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Show Red-Letter (Jesus\' words)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            // Italics toggle
            Row(
              children: [
                Switch(
                  value: showItalics,
                  onChanged: (value) {
                    setState(() {
                      showItalics = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Show Italics (added text)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _parseDirectly,
              child: const Text('Parse Directly'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : _showOpenBiblesDialog,
              child: const Text('Load from open-bibles submodule'),
            ),
            const SizedBox(height: 20),

            // Book and Chapter selection
            if (repository != null) ...[
              Text('View Verses by Book and Chapter:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              // Use Column instead of Row for better layout with long book titles
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Book dropdown
                  DropdownButtonFormField<Book>(
                    isExpanded: true, // Ensure dropdown expands to full width
                    decoration: const InputDecoration(
                      labelText: 'Select Book',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    value: selectedBook,
                    items: books.map((book) {
                      return DropdownMenuItem<Book>(
                        value: book,
                        child: Text(
                          '${book.num}. ${book.title}',
                          overflow: TextOverflow
                              .ellipsis, // Handle text overflow gracefully
                        ),
                      );
                    }).toList(),
                    onChanged: (Book? book) {
                      setState(() {
                        selectedBook = book;
                        selectedChapter = null;
                        _updateAvailableChapters();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Chapter dropdown
                  DropdownButtonFormField<int>(
                    isExpanded: true, // Ensure dropdown expands to full width
                    decoration: const InputDecoration(
                      labelText: 'Select Chapter',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    value: selectedChapter,
                    items: availableChapters.map((chapter) {
                      return DropdownMenuItem<int>(
                        value: chapter,
                        child: Text('Chapter $chapter'),
                      );
                    }).toList(),
                    onChanged: selectedBook == null
                        ? null
                        : (int? chapter) {
                            setState(() {
                              selectedChapter = chapter;
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: (selectedBook != null && selectedChapter != null)
                    ? _loadVerses
                    : null,
                child: const Text('Load Verses'),
              ),
            ],
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SelectableText(
                      result,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Test the original parser with our fix
  Future<void> _parseDirectly() async {
    setState(() {
      isLoading = true;
      result = 'Testing parser...';
    });

    try {
      // Load the XML content from assets
      final xmlString =
          await DefaultAssetBundle.of(context).loadString(xmlPath);

      // Create the original parser with the XML string
      final parser = BibleParser.fromString(xmlString,
          format: currentFormat.name.toUpperCase());

      // Set up a timeout
      bool timedOut = false;
      final timeout = Timer(const Duration(seconds: 30), () {
        // Parsing timed out
        timedOut = true;
        if (!mounted) return;
        setState(() {
          result +=
              '\n\nParsing timed out after 30 seconds. There may be an issue with the parser.';
          isLoading = false;
        });
      });

      // Collect verses from the parser
      final verses = <Verse>[];
      int count = 0;

      final subscription = parser.verses.listen(
        (verse) {
          verses.add(verse);
          count++;

          if (count % 5 == 0 && mounted) {
            setState(() {
              result = 'Parsing...\n\nParsed ${verses.length} verses so far';
            });
          }
        },
        onError: (e) {},
        onDone: () {},
      );

      // Wait for parsing to complete or timeout
      await Future.delayed(const Duration(seconds: 20));
      subscription.cancel();
      timeout.cancel();

      if (!timedOut && mounted) {
        if (verses.isEmpty) {
          setState(() {
            result = 'Parser: No verses were parsed.';
            isLoading = false;
          });
        } else {
          // Build result with red-letter support
          final buffer = StringBuffer();
          buffer.writeln('Parser Results (${verses.length} verses):');
          buffer.writeln();

          for (final v in verses) {
            buffer.write('${v.bookId} ${v.chapterNum}:${v.num} - ');
            if ((showRedLetter || showItalics) &&
                v.segments != null &&
                v.segments!.isNotEmpty) {
              // Has segments - show with styling indicators
              for (final segment in v.segments!) {
                if (showRedLetter &&
                    segment.isJesus &&
                    showItalics &&
                    segment.isAdded) {
                  buffer.write('[JESUS+ITALIC: ${segment.text}] ');
                } else if (showRedLetter && segment.isJesus) {
                  buffer.write('[JESUS: ${segment.text}] ');
                } else if (showItalics && segment.isAdded) {
                  buffer.write('[ITALIC: ${segment.text}] ');
                } else {
                  buffer.write('${segment.text} ');
                }
              }
            } else {
              // No segments or toggles off - show plain text
              buffer.write(v.text);
            }
            buffer.writeln();
            buffer.writeln();
          }

          setState(() {
            result = buffer.toString();
            isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          result = 'Parser error: ${e.toString()}\n\nStack trace:\n$stackTrace';
          isLoading = false;
        });
      }
    }
  }

  // Show dialog to select a Bible file from the open-bibles submodule
  Future<void> _showOpenBiblesDialog() async {
    setState(() {
      isLoading = true;
      result = 'Loading Bible files from assets...';
    });

    try {
      // Load the manifest to find Bible files in assets
      final manifestContent =
          await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Filter for XML files in open-bibles that match our criteria
      final files = manifestMap.keys
          .where((String key) =>
              key.startsWith('assets/open-bibles/') &&
              key.endsWith('.xml') &&
              (key.contains('eng-asv') ||
                  key.contains('eng-kjv') ||
                  key.contains('eng-web')))
          .toList();

      if (files.isEmpty) {
        setState(() {
          result = 'Error: No Bible files found in assets';
          isLoading = false;
        });
        return;
      }

      setState(() {
        result = 'Found ${files.length} Bible files in assets';
      });

      setState(() {
        isLoading = false;
      });

      if (files.isEmpty) {
        setState(() {
          result = 'Error: No XML files found in open-bibles submodule';
        });
        return;
      }

      // Sort files by name
      files.sort();

      if (!mounted) return;

      // Show dialog to select a file
      final selectedFile = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Bible File'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final fileName = path.basename(file);
                return ListTile(
                  title: Text(fileName),
                  onTap: () => Navigator.of(context).pop(file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFile == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Process the selected file
      final fileName = path.basename(selectedFile);
      setState(() {
        selectedSubmoduleFile = selectedFile;
        isUsingSubmodule = true;

        // Determine format from file extension
        if (fileName.contains('eng-asv')) {
          currentFormat = BibleFormat.zefania;
        } else if (fileName.contains('.osis.')) {
          currentFormat = BibleFormat.osis;
        } else if (fileName.contains('.usfx.')) {
          currentFormat = BibleFormat.usfx;
        } else if (fileName.contains('.zefania.')) {
          currentFormat = BibleFormat.zefania;
        } else {
          // Default to OSIS if format can't be determined
          currentFormat = BibleFormat.osis;
        }
      });

      _loadBibleFromAssets(selectedFile);
    } catch (e) {
      setState(() {
        result = 'Error scanning open-bibles: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Format determination is now done inline when processing the selected file

  // Load Bible from assets
  Future<void> _loadBibleFromAssets(String assetPath) async {
    setState(() {
      isLoading = true;
      result = 'Loading Bible from assets...';
      isFullBible = true;
    });

    try {
      final stopwatch = Stopwatch()..start();
      final fileName = path.basename(assetPath);

      // Read the file content from assets
      final xmlString =
          await DefaultAssetBundle.of(context).loadString(assetPath);

      final format = currentFormat.name.toUpperCase();

      setState(() {
        result =
            'Bible file loaded. Initializing repository with $format format...';
      });

      // Initialize the repository with the XML string
      repository = BibleRepository.fromString(
        xmlString: xmlString,
        format: format,
      );

      final databaseName = '${assetPath.split('/').last.split('.').first}.db';
      debugPrint("Database name: $databaseName");
      await repository!.initialize(databaseName);
      stopwatch.stop();

      // Get available books
      books = await repository!.getBooks();

      // Update UI with first book selected
      if (books.isNotEmpty) {
        selectedBook = books.first;
        await _updateAvailableChapters();
      }

      setState(() {
        result =
            'Bible loaded from assets in ${stopwatch.elapsedMilliseconds}ms\n\n'
            'File: $fileName\n'
            'Asset Path: $assetPath\n'
            'Format: $format\n'
            'Books: ${books.length}\n\n'
            '${books.map((b) => '${b.num}. ${b.title} (${b.id})').join('\n')}';
      });
    } catch (e, stackTrace) {
      setState(() {
        result =
            'Error loading Bible from assets: ${e.toString()}\n\n$stackTrace';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update the available chapters based on the selected book
  Future<void> _updateAvailableChapters() async {
    if (repository == null ||
        selectedBook == null ||
        selectedBook!.id == "Unknown") {
      return;
    }

    try {
      final chapterCount = await repository!.getChapterCount(selectedBook!.id);
      setState(() {
        availableChapters = List.generate(chapterCount, (i) => i + 1);
        if (availableChapters.isNotEmpty) {
          selectedChapter = 1; // Default to first chapter
        } else {
          selectedChapter = null;
        }
      });
    } catch (e) {
      setState(() {
        availableChapters = [];
        selectedChapter = null;
        result = 'Error loading chapters: ${e.toString()}';
      });
    }
  }

  // Load verses for the selected book and chapter
  Future<void> _loadVerses() async {
    if (repository == null || selectedBook == null || selectedChapter == null) {
      return;
    }

    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      final stopwatch = Stopwatch()..start();
      final verses =
          await repository!.getVerses(selectedBook!.id, selectedChapter!);
      stopwatch.stop();

      // Build rich text with red-letter support
      final buffer = StringBuffer();
      buffer.writeln('${selectedBook!.title} Chapter $selectedChapter');
      buffer.writeln(
          'Loaded ${verses.length} verses in ${stopwatch.elapsedMilliseconds}ms');
      buffer.writeln();

      for (final verse in verses) {
        buffer.write('Verse ${verse.num}: ');
        if ((showRedLetter || showItalics) &&
            verse.segments != null &&
            verse.segments!.isNotEmpty) {
          // Has segments - show with styling indicators
          for (final segment in verse.segments!) {
            if (showRedLetter &&
                segment.isJesus &&
                showItalics &&
                segment.isAdded) {
              buffer.write('[JESUS+ITALIC: ${segment.text}] ');
            } else if (showRedLetter && segment.isJesus) {
              buffer.write('[JESUS: ${segment.text}] ');
            } else if (showItalics && segment.isAdded) {
              buffer.write('[ITALIC: ${segment.text}] ');
            } else {
              buffer.write('${segment.text} ');
            }
          }
        } else {
          // No segments or toggles off - show plain text
          buffer.write(verse.text);
        }
        buffer.writeln();
        buffer.writeln();
      }

      setState(() {
        result = buffer.toString();
      });
    } catch (e) {
      setState(() {
        result = 'Error loading verses: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
