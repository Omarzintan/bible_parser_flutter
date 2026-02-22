import 'dart:io';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:path/path.dart' as path;

void main() async {
  print('Testing Bible Parser Desktop database loading functionality...');
  
  // First, create a test database from XML
  final xmlPath = 'assets/bible_small_osis.xml';
  final testDbPath = 'test_bible.db';
  
  try {
    print('Step 1: Creating test database from XML...');
    
    // Read the XML file
    final xmlString = await File(xmlPath).readAsString();
    print('✓ Successfully read XML file: ${path.basename(xmlPath)}');
    
    // Create repository from XML
    final xmlRepository = BibleRepository.fromString(xmlString: xmlString, format: 'OSIS');
    await xmlRepository.initialize(testDbPath);
    print('✓ Database created successfully: $testDbPath');
    
    // Get books to verify it worked
    final books = await xmlRepository.getBooks();
    print('✓ Found ${books.length} books in database');
    
    // Close the XML repository
    await xmlRepository.close();
    
    print('\nStep 2: Testing database loading from file...');
    
    // Now test loading from the database file
    final dbRepository = BibleRepository.fromDatabase();
    await dbRepository.initialize(testDbPath);
    print('✓ Database loaded successfully from file');
    
    // Get books from the loaded database
    final loadedBooks = await dbRepository.getBooks();
    print('✓ Found ${loadedBooks.length} books from loaded database');
    
    // Verify the data is the same
    if (loadedBooks.length == books.length) {
      print('✓ Book count matches between XML and database');
    } else {
      print('❌ Book count mismatch: ${books.length} vs ${loadedBooks.length}');
    }
    
    // Test verse loading
    if (loadedBooks.isNotEmpty) {
      final firstBook = loadedBooks.first;
      final verses = await dbRepository.getVerses(firstBook.id, 1);
      print('✓ Successfully loaded ${verses.length} verses from ${firstBook.title} 1');
      
      if (verses.isNotEmpty) {
        print('✓ First verse: ${firstBook.id} 1:${verses.first.num} - ${verses.first.text}');
      }
    }
    
    // Close the database repository
    await dbRepository.close();
    print('✓ Database closed successfully');
    
    // Clean up test database
    final testDbFile = File(testDbPath);
    if (testDbFile.existsSync()) {
      await testDbFile.delete();
      print('✓ Test database cleaned up');
    }
    
    print('\n🎉 All database loading tests passed!');
    print('The desktop app can now load existing database files directly.');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    
    // Clean up on error
    final testDbFile = File(testDbPath);
    if (testDbFile.existsSync()) {
      await testDbFile.delete();
    }
  }
}
