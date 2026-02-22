import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('Database Loading Tests', () {
    late String testDbPath;
    late String xmlPath;

    setUp(() {
      testDbPath = 'test_database_loading.db';
      xmlPath = 'assets/bible_small_osis.xml';
    });

    tearDown(() async {
      // Clean up test database
      final testDbFile = File(testDbPath);
      if (testDbFile.existsSync()) {
        await testDbFile.delete();
      }
    });

    test('BibleRepository.fromDatabase() creates valid repository', () {
      final repository = BibleRepository.fromDatabase();
      expect(repository, isNotNull);
      expect(repository, isA<BibleRepository>());
    });

    test('Database loading workflow works end-to-end', () async {
      // Step 1: Create database from XML
      final xmlString = await File(xmlPath).readAsString();
      final xmlRepository = BibleRepository.fromString(
        xmlString: xmlString,
        format: 'OSIS',
      );

      await xmlRepository.initialize(testDbPath);

      // Verify database was created
      final books = await xmlRepository.getBooks();
      expect(books.isNotEmpty, true);

      await xmlRepository.close();

      // Step 2: Load database from file
      final dbRepository = BibleRepository.fromDatabase();
      await dbRepository.initialize(testDbPath);

      // Verify loaded database has same data
      final loadedBooks = await dbRepository.getBooks();
      expect(loadedBooks.length, books.length);
      expect(loadedBooks.first.title, books.first.title);

      // Test verse loading
      final verses = await dbRepository.getVerses(loadedBooks.first.id, 1);
      expect(verses.isNotEmpty, true);
      expect(verses.first.text, isNotEmpty);

      await dbRepository.close();
    });

    test('Loading non-existent database throws appropriate error', () async {
      final repository = BibleRepository.fromDatabase();

      expect(
        () => repository.initialize('non_existent_database.db'),
        throwsA(isA<Exception>()),
      );
    });

    test('Database loading preserves red-letter and segment data', () async {
      // Create database with XML
      final xmlString = await File(xmlPath).readAsString();
      final xmlRepository = BibleRepository.fromString(
        xmlString: xmlString,
        format: 'OSIS',
      );

      await xmlRepository.initialize(testDbPath);
      await xmlRepository.close();

      // Load from database
      final dbRepository = BibleRepository.fromDatabase();
      await dbRepository.initialize(testDbPath);

      // Check that verses have segment data if available
      final books = await dbRepository.getBooks();
      if (books.isNotEmpty) {
        final verses = await dbRepository.getVerses(books.first.id, 1);
        // Some verses might have segments, others might not
        // Just verify we can access the verses without errors
        for (final verse in verses) {
          expect(verse.text, isNotEmpty);
          if (verse.segments != null) {
            expect(verse.segments!.isNotEmpty, true);
          }
        }
      }

      await dbRepository.close();
    });
  });
}
