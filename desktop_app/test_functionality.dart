import 'dart:io';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:path/path.dart' as path;

void main() async {
  print('Testing Bible Parser Desktop functionality...');
  
  // Test with one of the example files
  final xmlPath = 'assets/bible_small_osis.xml';
  
  try {
    // Read the XML file
    final xmlString = await File(xmlPath).readAsString();
    print('✓ Successfully read XML file: ${path.basename(xmlPath)}');
    
    // Create parser
    final parser = BibleParser.fromString(xmlString, format: 'OSIS');
    print('✓ Parser created successfully');
    
    // Create repository
    final repository = BibleRepository.fromString(xmlString: xmlString, format: 'OSIS');
    await repository.initialize('test.db');
    print('✓ Database created successfully');
    
    // Get books
    final books = await repository.getBooks();
    print('✓ Found ${books.length} books');
    
    if (books.isNotEmpty) {
      final firstBook = books.first;
      print('✓ First book: ${firstBook.title} (${firstBook.id})');
      
      // Get verses from first chapter
      final verses = await repository.getVerses(firstBook.id, 1);
      print('✓ Found ${verses.length} verses in ${firstBook.title} 1');
      
      if (verses.isNotEmpty) {
        print('✓ First verse: ${firstBook.id} 1:${verses.first.num} - ${verses.first.text}');
      }
    }
    
    // Close repository
    await repository.close();
    print('✓ Database closed successfully');
    
    // Clean up test database
    final testDb = File('test.db');
    if (testDb.existsSync()) {
      await testDb.delete();
      print('✓ Test database cleaned up');
    }
    
    print('\n🎉 All tests passed! Desktop app functionality is working.');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
}
