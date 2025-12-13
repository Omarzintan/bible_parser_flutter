import 'dart:async';
import 'dart:io';

// import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'sqflite_factory.dart';

import 'bible_parser.dart';
import 'book.dart';
import 'verse.dart';

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

  /// Creates a new Bible repository from a file path.
  BibleRepository({
    required this.xmlPath,
    this.format,
  }) : xmlString = null;

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
      
      // Check if database exists and is current version
      final dbInitialized = await _isDatabaseInitialized(databaseName);

      if (!dbInitialized) {
        // Create database from XML
        await _createDatabaseFromXml(databaseName);
      } else {
        // Open database connection
        _database = await _openDatabase(databaseName);
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
          final verses = <Map<String, dynamic>>[];
          
          // First collect all data
          await for (final book in parser.books) {
            books.add(book.toMap());
            if (book.verses.isNotEmpty) {
              for (final verse in book.verses) {
                verses.add(verse.toMap());
              }
            }
          }
          
          // Then batch insert books
          for (final book in books) {
            try {
              await txn.insert(
                'books', 
                book,
                conflictAlgorithm: ConflictAlgorithm.ignore, // Skip if already exists
              );
            } catch (e) {
              // Continue with next book
            }
          }
          
          // Then batch insert verses
          for (final verse in verses) {
            try {
              await txn.insert(
                'verses', 
                verse,
                conflictAlgorithm: ConflictAlgorithm.ignore, // Skip if already exists
              );
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

  // Database versioning is handled by openDatabase. Just close.
  // Keep the database open for repository use
  }

  /// Opens the database.
  Future<Database> _openDatabase(String databaseName) async {
    final dbPath = await _getDatabasePath(databaseName);
    
    return databaseFactoryPlatform.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
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
          FOREIGN KEY (book_id) REFERENCES books (id)
        )
      ''');

        // Create indexes for fast lookup
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_verses_lookup ON verses (book_id, chapter_num, verse_num)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_verses_search ON verses (text)');
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
    return join(base, databaseName);
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

  /// Gets all verses in a chapter.
  Future<List<Verse>> getVerses(String bookId, int chapterNum) async {
    _ensureDatabaseInitialized();
    final maps = await _database!.query('verses',
        where: 'book_id = ? AND chapter_num = ?',
        whereArgs: [bookId, chapterNum],
        orderBy: 'verse_num');
    return maps.map((map) => Verse.fromMap(map)).toList();
  }

  /// Searches for verses containing the given query.
  Future<List<Verse>> searchVerses(String query) async {
    _ensureDatabaseInitialized();
    final maps = await _database!.query('verses',
        where: 'text LIKE ?', whereArgs: ['%$query%'], limit: 100);
    return maps.map((map) => Verse.fromMap(map)).toList();
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

    return Verse.fromMap(maps.first);
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
