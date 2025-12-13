# Bible Parser Flutter

A Flutter package for parsing Bible texts in various XML formats (USFX, OSIS, ZEFANIA). This package provides both direct parsing and database-backed approaches for handling Bible data in your Flutter applications. The parser is optimized for production use with proper error handling.

## Features

- **🆕 Red-Letter Bible Support** - Identify and style Jesus' words in OSIS and USFX formats
- Parse Bible texts in multiple formats (USFX, OSIS, ZEFANIA)
- Automatic format detection
- Memory-efficient SAX-style XML parsing using proper async streams
- **Note:** This package has only been tested to work with the XML files under example/assets/open-bibles. Users are welcome to try the parser with other XML files and create a GitHub issue if they encounter any errors.
- Database caching with automatic segment persistence
- Search functionality for verses
- Retrieve verses by book and chapter
- Cross-platform support (iOS, Android, Web, Windows, Linux, macOS)

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  bible_parser_flutter: ^0.2.0
```

Then run:

```bash
flutter pub get
```

### Prerequisites

- Flutter SDK
- A Bible XML file in one of the supported formats (USFX, OSIS, ZEFANIA)

## Usage

### Direct Parsing Approach

Parse a Bible file directly without database caching. This is simpler but less efficient for repeated access:

```dart
import 'dart:io';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

Future<void> parseBible() async {
   // Load the XML content from assets
   final xmlString =
       await DefaultAssetBundle.of(context).loadString(xmlPath);

   // Create the original parser with the XML string
   final parser = BibleParser.fromString(xmlString,
       format: currentFormat.name.toUpperCase());
  
  // Access books
  await for (final book in parser.books) {
    print('${book.title} (${book.id})');
    
    // Access chapters and verses
    for (final chapter in book.chapters) {
      for (final verse in chapter.verses) {
        print('${book.id} ${verse.chapterNum}:${verse.num} - ${verse.text}');
      }
    }
  }
  
  // Or access all verses directly
  await for (final verse in parser.verses) {
    print('${verse.bookId} ${verse.chapterNum}:${verse.num} - ${verse.text}');
  }
}
```

### Database Approach (Recommended for Production)

For better performance, especially in production apps, use the database approach:

```dart
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

Future<void> useBibleRepository() async {
  // Create a repository
  final repository = BibleRepository.fromString(
    xmlString: 'path/to/bible.xml',
    format: 'USFX',
  );
  
  // Initialize the database (parses XML and stores in SQLite)
  // This only needs to be done once, typically on first app launch
  await repository.initialize('some_database_name.db');
  
  // Get all books
  final books = await repository.getBooks();
  for (final book in books) {
    print('${book.title} (${book.id})');
  }
  
  // Get verses from a specific chapter
  final verses = await repository.getVerses('gen', 1);
  for (final verse in verses) {
    print('${verse.bookId} ${verse.chapterNum}:${verse.num} - ${verse.text}');
  }
  
  // Search for verses containing specific text
  final searchResults = await repository.searchVerses('love');
  print('Found ${searchResults.length} verses containing "love"');
  
  // Don't forget to close the database when done
  await repository.close();
}
```

### Red-Letter Bible Support (New in v0.2.0)

Access Jesus' words with text segments:

```dart
// Parse a Bible with red-letter support
final parser = BibleParser.fromString(xmlString, format: 'OSIS');

await for (final verse in parser.verses) {
  // Check if verse contains Jesus' words
  if (verse.hasJesusWords) {
    print('Verse ${verse.chapterNum}:${verse.num} has Jesus speaking!');
    
    // Access individual segments
    for (final segment in verse.segments!) {
      if (segment.isJesus) {
        // Display in red or special styling
        print('Jesus said: "${segment.text}"');
      } else {
        // Display normally
        print('Narrator: "${segment.text}"');
      }
    }
  }
  
  // Or just use the full text (backward compatible)
  print(verse.text);
}
```

**Supported formats:**
- OSIS: `<q who="Jesus">` tags
- USFX: `<wj>` (Words of Jesus) tags

**Database persistence:** Segments are automatically saved and loaded from the database when using `BibleRepository`.

For more details, see the [Red-Letter Bible Support documentation](/doc/red-letter-bible-support.md).

## Performance Considerations

### Direct Parsing

- Simple implementation
- No database setup required
- Always uses the latest source files
- CPU and memory intensive
- Slower initial load times
- Higher battery consumption
- Repeated parsing on each access

### Database Approach

- Much faster access once data is loaded
- Lower memory usage during normal operation
- Better user experience with instant search and navigation
- Reduced battery consumption
- Works offline without re-parsing
- Requires initial setup complexity

## Example

See the `/example` folder for a complete working example of both approaches. The example app demonstrates:

- Parsing Bible files in OSIS and USFX formats
- Database initialization and querying
- Browsing verses by book and chapter selection

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

Inspired by the Ruby [bible_parser](https://github.com/seven1m/bible_parser) library.

Bible XML files in the example are from the [open-bibles](https://github.com/seven1m/open-bibles) GitHub repository.
