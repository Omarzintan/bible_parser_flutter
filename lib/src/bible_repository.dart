import 'dart:async';
import 'dart:io';

// import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'sqflite_factory.dart';

import 'dart:convert';

import 'bible_parser.dart';
import 'book.dart';
import 'verse.dart';
import 'text_segment.dart';
import 'footnote.dart';

/// Repository for accessing Bible data with database caching.
class BibleRepository {
  /// The database instance.
  Database? _database;

  /// The path to the XML file.
  final String xmlPath;

  /// The XML content as a string (used when loading from assets in web).
  final String? xmlString;

  /// The format of the Bible data.
  final String? format;

  /// The actual database file path (set during initialization).
  String? _databaseFilePath;

  /// Creates a new Bible repository from a file path.
  BibleRepository({
    required this.xmlPath,
    this.format,
  }) : xmlString = null;

  /// Creates a new Bible repository from an existing database file.
  ///
  /// This constructor is used when you have a pre-created database file
  /// and want to access it without parsing XML.
  BibleRepository.fromDatabase()
      : xmlPath = '',
        xmlString = null,
        format = null;

  /// Creates a new Bible repository from XML content as a string.
  ///
  /// This is useful for web applications where direct file access is not available.
  BibleRepository.fromString({
    required this.xmlString,
    this.format,
  }) : xmlPath = '';

  /// Initializes the repository.
  ///
  /// This will create the database if it doesn't exist, or open it if it does.
  Future<bool> initialize(String databaseName) async {
    try {
      // Close any existing database connection
      try {
        if (_database != null) {
          await _database!.close();
        }
      } catch (e) {
        // Ignore errors when closing
      }

      // Get the actual database file path
      _databaseFilePath = await _getDatabasePath(databaseName);

      // Check if database is already initialized
      final dbInitialized = await _isDatabaseInitialized(databaseName);

      if (!dbInitialized) {
        // For fromDatabase case, we can't create without XML
        if (xmlPath.isEmpty && xmlString == null) {
          throw Exception(
              'Database does not exist and no XML source provided for creation');
        }
        // Create database from XML
        await _createDatabaseFromXml(databaseName);
      } else {
        // Open database connection
        _database = await _openDatabase(databaseName);

        // Check if database is empty (after migration) - only for XML-based repos
        if (xmlPath.isNotEmpty || xmlString != null) {
          final result =
              await _database!.rawQuery('SELECT COUNT(*) FROM books');
          final bookCount = result.first.values.first as int;
          if (bookCount == 0) {
            // Database was cleared during migration, reparse
            await _createDatabaseFromXml(databaseName);
          }
        }
      }

      return true;
    } catch (e, stackTrace) {
      throw Exception('Failed to initialize Bible repository: $e, $stackTrace');
    }
  }

  /// Checks if the database is initialized.
  Future<bool> _isDatabaseInitialized(String databaseName) async {
    final dbPath = await _getDatabasePath(databaseName);

    final dbExists = await databaseFactoryPlatform.databaseExists(dbPath);
    if (!dbExists) {
      return false;
    }
    return true;
  }

  /// Creates the database from the XML file or string.
  Future<void> _createDatabaseFromXml(String databaseName) async {
    // Parse XML from file or string
    final BibleParser parser;
    if (xmlString != null) {
      // Use the XML string directly
      parser = BibleParser.fromString(xmlString!, format: format);
    } else {
      // Use the file path
      parser = BibleParser(File(xmlPath), format: format);
    }

    // Create database schema
    final db = await _openDatabase(databaseName);
    _database = db; // Set the database instance

    try {
      // Insert data in batches using a single transaction for better performance
      await db.transaction((txn) async {
        try {
          // Process books
          final books = <Map<String, dynamic>>[];
          final versesData = <Verse>[];

          // First collect all data
          await for (final book in parser.books) {
            books.add(book.toMap());
            if (book.verses.isNotEmpty) {
              versesData.addAll(book.verses);
            }
          }

          // Then batch insert books
          for (final book in books) {
            try {
              await txn.insert(
                'books',
                book,
                conflictAlgorithm:
                    ConflictAlgorithm.ignore, // Skip if already exists
              );
            } catch (e) {
              // Continue with next book
            }
          }

          // Then batch insert verses and their segments
          for (final verse in versesData) {
            try {
              // Insert verse and get its ID
              final verseId = await txn.insert(
                'verses',
                verse.toMap(),
                conflictAlgorithm:
                    ConflictAlgorithm.ignore, // Skip if already exists
              );

              // Insert segments if present
              if (verse.segments != null && verse.segments!.isNotEmpty) {
                for (int i = 0; i < verse.segments!.length; i++) {
                  final segment = verse.segments![i];
                  await txn.insert(
                    'verse_segments',
                    {
                      'verse_id': verseId,
                      'segment_order': i,
                      'text': segment.text,
                      'attributes': segment.attributes != null
                          ? jsonEncode(segment.attributes)
                          : null,
                    },
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }

              // Insert footnotes if present
              if (verse.footnotes != null && verse.footnotes!.isNotEmpty) {
                for (final footnote in verse.footnotes!) {
                  await txn.insert(
                    'verse_footnotes',
                    footnote.toMap(verseId),
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }
            } catch (e) {
              // Continue with next verse
            }
          }
        } catch (e, stackTrace) {
          throw Exception('Failed to process Bible data: $e, $stackTrace');
        }
      });
    } catch (e, stackTrace) {
      throw Exception('Failed to create Bible database: $e, $stackTrace');
    }

    // Set database version (version is already set in onCreate, so this is redundant)
    // Keep database open for use
  }

  /// Opens the database.
  Future<Database> _openDatabase(String databaseName) async {
    final dbPath = await _getDatabasePath(databaseName);

    return databaseFactoryPlatform.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5, // Incremented for footnotes support
        onCreate: (db, version) async {
          // Create tables
          await db.execute('''
        CREATE TABLE IF NOT EXISTS books (
          id TEXT PRIMARY KEY,
          num INTEGER,
          title TEXT
        )
      ''');

          await db.execute('''
        CREATE TABLE IF NOT EXISTS verses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id TEXT,
          chapter_num INTEGER,
          verse_num INTEGER,
          text TEXT,
          FOREIGN KEY (book_id) REFERENCES books (id),
          UNIQUE(book_id, chapter_num, verse_num)
        )
      ''');

          // Create segments table for red-letter Bible support
          await db.execute('''
        CREATE TABLE IF NOT EXISTS verse_segments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          verse_id INTEGER NOT NULL,
          segment_order INTEGER NOT NULL,
          text TEXT NOT NULL,
          attributes TEXT,
          FOREIGN KEY (verse_id) REFERENCES verses (id) ON DELETE CASCADE
        )
      ''');

          // Create footnotes table
          await db.execute('''
        CREATE TABLE IF NOT EXISTS verse_footnotes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          verse_id INTEGER NOT NULL,
          footnote_id TEXT NOT NULL,
          marker TEXT NOT NULL,
          content TEXT NOT NULL,
          FOREIGN KEY (verse_id) REFERENCES verses (id) ON DELETE CASCADE
        )
      ''');

          // Create indexes for fast lookup
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_verses_lookup ON verses (book_id, chapter_num, verse_num)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_verses_search ON verses (text)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_segments_verse ON verse_segments (verse_id)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_footnotes_verse ON verse_footnotes (verse_id)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Handle migration from version 1 to 2
          if (oldVersion < 2) {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS verse_segments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              verse_id INTEGER NOT NULL,
              segment_order INTEGER NOT NULL,
              text TEXT NOT NULL,
              attributes TEXT,
              FOREIGN KEY (verse_id) REFERENCES verses (id) ON DELETE CASCADE
            )
          ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_segments_verse ON verse_segments (verse_id)');
          }

          // Handle migration from version 2 to 3 (transChange support)
          // The schema is the same, but we need to reparse to capture transChange attributes
          if (oldVersion < 3) {
            // Delete all data to force a complete reparse with transChange support
            await db.execute('DELETE FROM verse_segments');
            await db.execute('DELETE FROM verses');
            await db.execute('DELETE FROM books');
            // The data will be reparsed during initialization
          }

          // Handle migration from version 3 to 4 (UNIQUE constraint on verses)
          // Need to recreate verses table with UNIQUE constraint
          if (oldVersion < 4) {
            // Delete all data and recreate table with UNIQUE constraint
            await db.execute('DROP TABLE IF EXISTS verse_segments');
            await db.execute('DROP TABLE IF EXISTS verses');

            // Recreate verses table with UNIQUE constraint
            await db.execute('''
              CREATE TABLE verses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id TEXT,
                chapter_num INTEGER,
                verse_num INTEGER,
                text TEXT,
                FOREIGN KEY (book_id) REFERENCES books (id),
                UNIQUE(book_id, chapter_num, verse_num)
              )
            ''');

            // Recreate segments table
            await db.execute('''
              CREATE TABLE verse_segments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                verse_id INTEGER NOT NULL,
                segment_order INTEGER NOT NULL,
                text TEXT NOT NULL,
                attributes TEXT,
                FOREIGN KEY (verse_id) REFERENCES verses (id) ON DELETE CASCADE
              )
            ''');

            // Recreate indexes
            await db.execute(
                'CREATE INDEX idx_verses_lookup ON verses (book_id, chapter_num, verse_num)');
            await db.execute('CREATE INDEX idx_verses_search ON verses (text)');
            await db.execute(
                'CREATE INDEX idx_segments_verse ON verse_segments (verse_id)');

            // Delete books to force complete reparse
            await db.execute('DELETE FROM books');
            // The data will be reparsed during initialization
          }

          // Handle migration from version 4 to 5 (footnotes support)
          if (oldVersion < 5) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS verse_footnotes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                verse_id INTEGER NOT NULL,
                footnote_id TEXT NOT NULL,
                marker TEXT NOT NULL,
                content TEXT NOT NULL,
                FOREIGN KEY (verse_id) REFERENCES verses (id) ON DELETE CASCADE
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_footnotes_verse ON verse_footnotes (verse_id)');
          }
        },
      ),
    );
  }

  /// Gets the path to the database file.
  Future<String> _getDatabasePath(String databaseName) async {
    final base = await getDatabasesPathPlatform();
    if (base.isEmpty) {
      return databaseName;
    }
    return p.join(base, databaseName);
  }

  /// Gets the current database file path.
  ///
  /// Returns the full path to the database file if the repository is initialized,
  /// otherwise returns null.
  Future<String?> getDatabasePath() async {
    return _databaseFilePath;
  }

  /// Ensures database is initialized before use
  void _ensureDatabaseInitialized() {
    if (_database == null) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
  }

  /// Gets all books in the Bible.
  Future<List<Book>> getBooks() async {
    _ensureDatabaseInitialized();
    final maps = await _database!.query('books', orderBy: 'num');
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  /// Gets the number of chapters in a book.
  Future<int> getChapterCount(String bookId) async {
    _ensureDatabaseInitialized();
    final result = await _database!.rawQuery(
        'SELECT COUNT(DISTINCT chapter_num) as count FROM verses WHERE book_id = ?',
        [bookId]);
    return result.first['count'] as int;
  }

  /// Loads footnotes for a verse from the database.
  Future<List<Footnote>?> _loadFootnotes(int verseId) async {
    final maps = await _database!.query(
      'verse_footnotes',
      where: 'verse_id = ?',
      whereArgs: [verseId],
      orderBy: 'id',
    );

    if (maps.isEmpty) return null;

    return maps.map((map) => Footnote.fromMap(map)).toList();
  }

  /// Loads segments for a verse from the database.
  Future<List<TextSegment>?> _loadSegments(int verseId) async {
    final segmentMaps = await _database!.query(
      'verse_segments',
      where: 'verse_id = ?',
      whereArgs: [verseId],
      orderBy: 'segment_order',
    );

    if (segmentMaps.isEmpty) {
      return null;
    }

    return segmentMaps.map((map) {
      Map<String, String>? attributes;
      if (map['attributes'] != null && map['attributes'] is String) {
        try {
          final decoded = jsonDecode(map['attributes'] as String);
          if (decoded is Map) {
            attributes = Map<String, String>.from(decoded);
          }
        } catch (e) {
          // If JSON parsing fails, ignore attributes
        }
      }

      return TextSegment(
        text: map['text'] as String,
        attributes: attributes,
      );
    }).toList();
  }

  /// Gets all verses in a chapter.
  Future<List<Verse>> getVerses(String bookId, int chapterNum) async {
    _ensureDatabaseInitialized();
    final maps = await _database!.query('verses',
        where: 'book_id = ? AND chapter_num = ?',
        whereArgs: [bookId, chapterNum],
        orderBy: 'verse_num');

    // Load verses with their segments
    final verses = <Verse>[];
    for (final map in maps) {
      final verseId = map['id'] as int;
      final segments = await _loadSegments(verseId);

      final footnotes = await _loadFootnotes(verseId);

      verses.add(Verse(
        num: map['verse_num'] as int,
        chapterNum: map['chapter_num'] as int,
        text: map['text'] as String,
        bookId: map['book_id'] as String,
        segments: segments,
        footnotes: footnotes,
      ));
    }

    return verses;
  }

  /// Searches for verses containing the given query.
  Future<List<Verse>> searchVerses(String query) async {
    _ensureDatabaseInitialized();
    final maps = await _database!.query('verses',
        where: 'text LIKE ?', whereArgs: ['%$query%'], limit: 100);

    // Load verses with their segments
    final verses = <Verse>[];
    for (final map in maps) {
      final verseId = map['id'] as int;
      final segments = await _loadSegments(verseId);

      final footnotes = await _loadFootnotes(verseId);

      verses.add(Verse(
        num: map['verse_num'] as int,
        chapterNum: map['chapter_num'] as int,
        text: map['text'] as String,
        bookId: map['book_id'] as String,
        segments: segments,
        footnotes: footnotes,
      ));
    }

    return verses;
  }

  /// Gets a specific verse.
  Future<Verse?> getVerse(String bookId, int chapterNum, int verseNum) async {
    _ensureDatabaseInitialized();
    final maps = await _database!.query('verses',
        where: 'book_id = ? AND chapter_num = ? AND verse_num = ?',
        whereArgs: [bookId, chapterNum, verseNum],
        limit: 1);

    if (maps.isEmpty) {
      return null;
    }

    final map = maps.first;
    final verseId = map['id'] as int;
    final segments = await _loadSegments(verseId);

    final footnotes = await _loadFootnotes(verseId);

    return Verse(
      num: map['verse_num'] as int,
      chapterNum: map['chapter_num'] as int,
      text: map['text'] as String,
      bookId: map['book_id'] as String,
      segments: segments,
      footnotes: footnotes,
    );
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
