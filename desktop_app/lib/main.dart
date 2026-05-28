import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:desktop_window/desktop_window.dart';

/// Enum for Bible formats supported by the app
enum BibleFormat { osis, usfx, zefania }

/// Enum for app modes
enum AppMode { createFromXml, loadFromDb }

void main() {
  runApp(const BibleParserDesktopApp());
}

class BibleParserDesktopApp extends StatelessWidget {
  const BibleParserDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible Parser Desktop',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BibleParserDesktopScreen(),
    );
  }
}

class BibleParserDesktopScreen extends StatefulWidget {
  const BibleParserDesktopScreen({super.key});

  @override
  State<BibleParserDesktopScreen> createState() =>
      _BibleParserDesktopScreenState();
}

class _BibleParserDesktopScreenState extends State<BibleParserDesktopScreen> {
  AppMode currentMode = AppMode.createFromXml;
  String? xmlFilePath;
  String? databaseFilePath;
  BibleFormat currentFormat = BibleFormat.osis;
  bool isLoading = false;
  String result = '';
  BibleRepository? repository;
  bool isFullBible = false;
  String? databasePath;

  // For verse viewing feature
  List<Book> books = [];
  Book? selectedBook;
  int? selectedChapter;
  List<int> availableChapters = [];

  // Red-letter display toggle
  bool showRedLetter = true;

  // Italicized text display toggle
  bool showItalics = true;

  // Footnotes display toggle
  bool showFootnotes = true;

  @override
  void initState() {
    super.initState();
    _setupDesktopWindow();
  }

  Future<void> _setupDesktopWindow() async {
    await DesktopWindow.setWindowSize(const Size(1200, 800));
    await DesktopWindow.setMinWindowSize(const Size(800, 600));
  }

  // Pick XML file using file picker
  Future<void> _pickXMLFile() async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
        allowMultiple: false,
      );

      if (pickerResult != null && pickerResult.files.single.path != null) {
        setState(() {
          xmlFilePath = pickerResult.files.single.path!;
          // Auto-detect format from filename
          final fileName = path.basename(xmlFilePath!);
          if (fileName.contains('.osis.')) {
            currentFormat = BibleFormat.osis;
          } else if (fileName.contains('.usfx.')) {
            currentFormat = BibleFormat.usfx;
          } else if (fileName.contains('.zefania.')) {
            currentFormat = BibleFormat.zefania;
          } else {
            currentFormat = BibleFormat.osis; // Default
          }
          result = 'Selected file: $fileName';
        });
      }
    } catch (e) {
      setState(() {
        result = 'Error picking file: ${e.toString()}';
      });
    }
  }

  // Pick database file using file picker
  Future<void> _pickDatabaseFile() async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        allowMultiple: false,
      );

      if (pickerResult != null && pickerResult.files.single.path != null) {
        setState(() {
          databaseFilePath = pickerResult.files.single.path!;
          result = 'Selected database: ${path.basename(databaseFilePath!)}';
        });
      }
    } catch (e) {
      setState(() {
        result = 'Error picking database file: ${e.toString()}';
      });
    }
  }

  // Download database file for user to save
  Future<void> _downloadDatabase() async {
    if (databasePath == null) return;

    try {
      final downloadPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Bible Database',
        fileName: path.basename(databasePath!),
        type: FileType.any,
      );

      if (downloadPath != null) {
        // Copy database file to user's chosen location
        final sourceFile = File(databasePath!);

        if (!await sourceFile.exists()) {
          throw Exception('Database file not found at: ${databasePath!}');
        }

        await sourceFile.copy(downloadPath);

        setState(() {
          result = 'Database saved successfully to:\n$downloadPath';
        });
      }
    } catch (e) {
      setState(() {
        result = 'Error saving database: ${e.toString()}';
      });
    }
  }

  // Load existing database from file
  Future<void> _loadDatabase() async {
    if (databaseFilePath == null) return;

    setState(() {
      isLoading = true;
      result = 'Loading database from file...';
    });

    try {
      final stopwatch = Stopwatch()..start();
      final fileName = path.basename(databaseFilePath!);

      // Create repository from database
      repository = BibleRepository.fromDatabase();

      // Initialize with the database file path
      await repository!.initialize(databaseFilePath!);

      // Get the actual database path from the repository
      final actualDbPath = await repository!.getDatabasePath();
      databasePath = actualDbPath;

      stopwatch.stop();

      // Get available books
      books = await repository!.getBooks();

      // Update UI with first book selected
      if (books.isNotEmpty) {
        selectedBook = books.first;
        await _updateAvailableChapters();
      }

      setState(() {
        isFullBible = true;
        databasePath = databaseFilePath;
        result =
            'Database loaded successfully in ${stopwatch.elapsedMilliseconds}ms\n\n'
            'File: $fileName\n'
            'Books: ${books.length}\n\n'
            '${books.map((b) => '${b.num}. ${b.title} (${b.id})').join('\n')}';
      });
    } catch (e, stackTrace) {
      setState(() {
        result = 'Error loading database: ${e.toString()}\n\n$stackTrace';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Create database from selected XML file
  Future<void> _createDatabase() async {
    if (xmlFilePath == null) return;

    setState(() {
      isLoading = true;
      result = 'Creating database from XML file...';
    });

    try {
      final stopwatch = Stopwatch()..start();
      final fileName = path.basename(xmlFilePath!);

      // Read the file content
      final xmlString = await File(xmlFilePath!).readAsString();

      final format = currentFormat.name.toUpperCase();
      setState(() {
        result = 'File loaded. Initializing repository with $format format...';
      });

      // Initialize the repository
      repository = BibleRepository.fromString(
        xmlString: xmlString,
        format: format,
      );

      // Create database with same name as XML file
      final databaseName = '${path.basenameWithoutExtension(xmlFilePath!)}.db';

      // Save to app's data directory (where we have permissions)
      final dbFilesDir = Directory(path.absolute('dbfiles'));
      if (!await dbFilesDir.exists()) {
        await dbFilesDir.create(recursive: true);
      }

      final savePath = path.join(dbFilesDir.path, databaseName);

      // Delete existing database to force a fresh parse (ensures latest features are included)
      final existingDb = File(savePath);
      if (await existingDb.exists()) {
        await existingDb.delete();
      }

      // Initialize the repository with the app's path
      await repository!.initialize(savePath);

      // Store the database path for reference (use the actual path from repository)
      databasePath = await repository!.getDatabasePath();

      stopwatch.stop();

      // Get available books
      books = await repository!.getBooks();

      // Update UI with first book selected
      if (books.isNotEmpty) {
        selectedBook = books.first;
        await _updateAvailableChapters();
      }

      setState(() {
        isFullBible = true;
        result =
            'Database created successfully in ${stopwatch.elapsedMilliseconds}ms\\n\\n'
            'File: $fileName\\n'
            'Format: $format\\n'
            'Database: $databaseName\\n'
            'Books: ${books.length}\\n\\n'
            '${books.map((b) => '${b.num}. ${b.title} (${b.id})').join('\\n')}';
      });
    } catch (e, stackTrace) {
      setState(() {
        result = 'Error creating database: ${e.toString()}\\n\\n$stackTrace';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible Parser Desktop'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode selection
            Text('Select Mode:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Radio<AppMode>(
                  value: AppMode.createFromXml,
                  groupValue: currentMode,
                  onChanged: (AppMode? value) {
                    setState(() {
                      currentMode = value!;
                      result = '';
                      repository = null;
                      books = [];
                      selectedBook = null;
                      selectedChapter = null;
                    });
                  },
                ),
                const Text('Create from XML'),
                const SizedBox(width: 20),
                Radio<AppMode>(
                  value: AppMode.loadFromDb,
                  groupValue: currentMode,
                  onChanged: (AppMode? value) {
                    setState(() {
                      currentMode = value!;
                      result = '';
                      repository = null;
                      books = [];
                      selectedBook = null;
                      selectedChapter = null;
                    });
                  },
                ),
                const Text('Load from Database'),
              ],
            ),
            const SizedBox(height: 20),

            // File selection based on mode
            if (currentMode == AppMode.createFromXml) ...[
              Text('Select Bible XML File:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickXMLFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Choose XML File'),
                  ),
                  const SizedBox(width: 20),
                  if (xmlFilePath != null)
                    Expanded(
                      child: Text(
                        'Selected: ${path.basename(xmlFilePath!)}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ] else ...[
              Text('Select Bible Database File:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickDatabaseFile,
                    icon: const Icon(Icons.storage),
                    label: const Text('Choose Database File'),
                  ),
                  const SizedBox(width: 20),
                  if (databaseFilePath != null)
                    Expanded(
                      child: Text(
                        'Selected: ${path.basename(databaseFilePath!)}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Action buttons based on mode
            Row(
              children: [
                if (currentMode == AppMode.createFromXml)
                  ElevatedButton(
                    onPressed: xmlFilePath != null ? _createDatabase : null,
                    child: const Text('Create Database'),
                  )
                else
                  ElevatedButton(
                    onPressed: databaseFilePath != null ? _loadDatabase : null,
                    child: const Text('Load Database'),
                  ),
                const SizedBox(width: 10),
                if (repository != null && currentMode == AppMode.createFromXml)
                  ElevatedButton.icon(
                    onPressed: _downloadDatabase,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (repository != null && currentMode == AppMode.createFromXml)
              const Text(
                'Database ready for download - click Download to save it anywhere',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Colors.green),
              ),
            const SizedBox(height: 16),

            // Display options in a more compact layout
            Row(
              children: [
                Expanded(
                  child: Row(
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
                      const Text('Red-Letter'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
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
                      const Text('Italics'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: showFootnotes,
                        onChanged: (value) {
                          setState(() {
                            showFootnotes = value;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Footnotes'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons based on mode
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
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: (selectedBook != null && selectedChapter != null)
                        ? _loadVerses
                        : null,
                    child: const Text('Load Verses'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Loading indicator or result display - make it flexible
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
      final book = selectedBook!;
      buffer.writeln(book.longTitle ?? book.title);
      if (book.shortTitle != null) buffer.writeln('Short: ${book.shortTitle}');
      if (book.abbreviation != null) {
        buffer.writeln('Abbreviation: ${book.abbreviation}');
      }
      buffer.writeln('Chapter $selectedChapter');
      buffer.writeln(
          'Loaded ${verses.length} verses in ${stopwatch.elapsedMilliseconds}ms');
      buffer.writeln();

      for (final verse in verses) {
        buffer.write('Verse ${verse.num}: ');
        if ((showRedLetter || showItalics || showFootnotes) &&
            verse.segments != null &&
            verse.segments!.isNotEmpty) {
          // Has segments - show with styling indicators
          for (final segment in verse.segments!) {
            if (segment.isFootnoteMarker) {
              // Insert footnote marker inline if footnotes are enabled
              if (showFootnotes && verse.footnotes != null) {
                final fn = verse.footnotes!.firstWhere(
                  (f) => f.id == segment.footnoteId,
                  orElse: () => verse.footnotes!.first,
                );
                buffer.write(fn.marker);
              }
            } else if (showRedLetter &&
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

        // Append footnote list below the verse
        if (showFootnotes && verse.hasFootnotes) {
          for (final fn in verse.footnotes!) {
            buffer.writeln('  ${fn.marker} ${fn.content}');
          }
        }
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
