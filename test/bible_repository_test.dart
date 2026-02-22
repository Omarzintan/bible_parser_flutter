import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('BibleRepository Constructor Tests', () {
    // Create a minimal sample XML for testing
    final sampleXml = '''
<?xml version="1.0" encoding="utf-8"?>
<osis xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
  <osisText osisIDWork="KJV">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">In the beginning God created the heaven and the earth.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';

    // Test file path
    final testFilePath = 'test_bible.xml';

    setUp(() {
      // Create a temporary file for testing
      final tempFile = File(testFilePath);
      tempFile.writeAsStringSync(sampleXml);
    });

    tearDown(() {
      // Clean up temporary file
      final tempFile = File(testFilePath);
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    test('BibleRepository.fromString constructor sets properties correctly',
        () {
      final repository = BibleRepository.fromString(xmlString: sampleXml);
      expect(repository.xmlString, equals(sampleXml));
      expect(repository.xmlPath, equals(''));
      expect(repository.format, isNull);
    });

    test(
        'BibleRepository.fromString constructor with format sets properties correctly',
        () {
      final repository =
          BibleRepository.fromString(xmlString: sampleXml, format: 'OSIS');
      expect(repository.xmlString, equals(sampleXml));
      expect(repository.xmlPath, equals(''));
      expect(repository.format, equals('OSIS'));
    });

    test('BibleRepository constructor sets properties correctly', () {
      final repository = BibleRepository(xmlPath: testFilePath);
      expect(repository.xmlPath, equals(testFilePath));
      expect(repository.xmlString, isNull);
      expect(repository.format, isNull);
    });

    test('BibleRepository constructor with format sets properties correctly',
        () {
      final repository = BibleRepository(xmlPath: testFilePath, format: 'OSIS');
      expect(repository.xmlPath, equals(testFilePath));
      expect(repository.xmlString, isNull);
      expect(repository.format, equals('OSIS'));
    });

    test('BibleRepository.fromDatabase constructor sets properties correctly',
        () {
      final repository = BibleRepository.fromDatabase();
      expect(repository.xmlPath, equals(''));
      expect(repository.xmlString, isNull);
      expect(repository.format, isNull);
    });
  });

  group('Book, Chapter, and Verse Model Tests', () {
    test('Book model works correctly', () {
      final book = Book(id: 'gen', num: 1, title: 'Genesis');
      expect(book.id, equals('gen'));
      expect(book.num, equals(1));
      expect(book.title, equals('Genesis'));

      // Test toMap and fromMap
      final map = book.toMap();
      final recreatedBook = Book.fromMap(map);
      expect(recreatedBook.id, equals('gen'));
      expect(recreatedBook.num, equals(1));
      expect(recreatedBook.title, equals('Genesis'));
    });

    test('Verse model works correctly', () {
      final verse = Verse(
          bookId: 'gen',
          chapterNum: 1,
          num: 1,
          text: 'In the beginning God created the heaven and the earth.');

      expect(verse.bookId, equals('gen'));
      expect(verse.chapterNum, equals(1));
      expect(verse.num, equals(1));
      expect(verse.text,
          equals('In the beginning God created the heaven and the earth.'));

      // Test toMap and fromMap
      final map = verse.toMap();
      final recreatedVerse = Verse.fromMap(map);
      expect(recreatedVerse.bookId, equals('gen'));
      expect(recreatedVerse.chapterNum, equals(1));
      expect(recreatedVerse.num, equals(1));
      expect(recreatedVerse.text,
          equals('In the beginning God created the heaven and the earth.'));
    });
  });

  group('BibleParser Factory Tests', () {
    test('BibleParser.fromString factory creates parser with string source',
        () {
      final xmlContent = '<osis><osisText></osisText></osis>';
      final parser = BibleParser.fromString(xmlContent);

      // We can't directly access private fields, but we can verify the parser was created
      expect(parser, isA<BibleParser>());
    });

    test(
        'BibleParser.fromString factory with format creates parser with correct format',
        () {
      final xmlContent = '<osis><osisText></osisText></osis>';
      final parser = BibleParser.fromString(xmlContent, format: 'OSIS');

      // We can't directly access private fields, but we can verify the parser was created
      expect(parser, isA<BibleParser>());
    });
  });
}
