# Bible Parser Flutter

A Flutter package for parsing Bible texts in OSIS, USFX, and ZEFANIA XML formats with both direct parsing and database-backed approaches. **Now includes a desktop app for Bible database creation and management!**

## 🆕 v0.3.0 Features

- ✅ **Desktop App**: Complete Bible database creation tool
- ✅ **Database Export**: User-controlled file saving
- ✅ **Database Loading**: Direct database file loading
- ✅ **Cross-Platform**: macOS, Windows, Linux support
- ✅ **Production Workflow**: XML → Database → Mobile App Distribution

## 📱 Desktop App Usage

### **Installation & Setup**
```bash
# Clone the repository to get the desktop app
git clone https://github.com/Omarzintan/bible_parser_flutter.git
cd bible_parser_flutter

# Navigate to desktop app
cd desktop_app
flutter pub get
flutter run -d macos  # or -d windows, -d linux
```

### **Alternative: Download Desktop App Only**
If you only want the desktop app without the full package:
```bash
# Clone and checkout only the desktop app
git clone --filter=blob:'desktop_app/*' https://github.com/Omarzintan/bible_parser_flutter.git
cd bible_parser_flutter/desktop_app
flutter pub get
flutter run -d macos
```

### **Workflow**
1. **Create Database**: Select XML file → Click "Create Database"
2. **Download**: Click "Download" → Choose save location (Desktop, Documents, etc.)
3. **Test**: Switch to "Load from Database" mode → Test exported file
4. **Deploy**: Upload db file to any storage service (Firebase, Google Drive, etc.) 

### **File Management**
- **Temporary Storage**: Databases created in app's `dbfiles/` directory
- **Persistence**: Files remain after stopping `flutter run`
- **Overwrite**: Creating same database name overwrites previous file
- **Download**: User saves to permanent location of their choice


## 📦 Package Contents

### **Core Library** (`lib/`)
- **Bible parsing** for OSIS, USFX, and ZEFANIA XML formats
- **Database repository** with SQLite caching
- **Text segments** for red-letter and added text support
- **Cross-platform** mobile and web support

### **Desktop App** (`desktop_app/`)
- **GUI tool** for Bible database creation and management
- **Cross-platform** desktop support (macOS, Windows, Linux)
- **File picker** integration for XML selection
- **Database export** with user-controlled saving
- **Database loading** for testing exported files
- **Production workflow** ready for Firebase distribution

> **Note**: The desktop app is included in the Git repository but excluded from the published Flutter package to keep the package size reasonable. Clone the repository to access the desktop app.

- **🆕 Red-Letter Bible Support** - Identify and style Jesus' words in OSIS and USFX formats
- **🆕 Added Text Support** - Track translator additions (italicized text) in OSIS and USFX formats
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
  bible_parser_flutter: ^0.3.0
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

### 🆕 Database Loading (Recommended for Production)

Load from pre-created database files for instant startup and optimal performance:

```dart
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

// Load from pre-created database file (instant startup)
final repository = BibleRepository.fromDatabase();
await repository.initialize('path/to/eng-kjv.osis.db');

// Get books, chapters, verses instantly (no XML parsing)
final books = await repository.getBooks();
final verses = await repository.getVerses('John', 1, 1);

// Support for red-letter and added text
for (final verse in verses) {
  for (final segment in verse.segments ?? []) {
    if (segment.isJesus) {
      // Render in red (Jesus' words)
      print('Jesus: "${segment.text}"');
    } else if (segment.isAdded) {
      // Render in italics (translator additions)
      print('Added: "${segment.text}"');
    } else {
      // Normal text
      print('Text: "${segment.text}"');
    }
  }
}

// Search functionality
final searchResults = await repository.searchVerses('love');
print('Found ${searchResults.length} verses containing "love"');

// Don't forget to close when done
await repository.close();
```

**Production Workflow:**
1. Use the **desktop app** to create database files from XML
2. Upload database files to Firebase Storage or cloud service
3. Download and load in mobile app using `BibleRepository.fromDatabase()`

**Benefits:**
- ⚡ **Instant startup** - No XML parsing needed
- 📱 **Mobile optimized** - Smaller app size, faster performance
- 🔄 **Easy updates** - Update databases without app updates
- 🎨 **Full features** - Red-letter, added text, search support

### Database Repository Approach

Parse XML and cache in a database for repeated access. This is more efficient for apps that need frequent Bible access:

```dart
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

// Parse XML and create database
final repository = BibleRepository.fromString(
  xmlString: xmlContent,
  format: 'OSIS', // or 'USFX', 'ZEFANIA'
);

await repository.initialize('my_bible.db');

// Get books
final books = await repository.getBooks();

// Get verses from a specific chapter
final verses = await repository.getVerses('gen', 1);
for (final verse in verses) {
  print('${verse.bookId} ${verse.chapterNum}:${verse.num} - ${verse.text}');
}

// Search for verses containing specific text
final searchResults = await repository.searchVerses('love');
print('Found ${searchResults.length} verses containing "love"');

// Don't forget to close when done
await repository.close();
```

**Use this approach when:**
- 📱 Building a Bible app with frequent access
- 🔄 Need to switch between books/chapters quickly
- 🔍 Want search functionality
- 💾 Have storage space for database caching

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

### Added/Italicized Text Support

The parser also tracks text marked as translator additions (typically italicized in printed Bibles):

```dart
// Get a verse with added text
final verse = await repository.getVerse('Matt', 27, 65);

if (verse.segments != null) {
  for (final segment in verse.segments!) {
    if (segment.isAdded) {
      // Display in italics (translator addition)
      print('Italic: "${segment.text}"');
    } else if (segment.isJesus) {
      // Display in red (Jesus' words)
      print('Red: "${segment.text}"');
    } else {
      // Display normally
      print('Normal: "${segment.text}"');
    }
  }
}
```

**Supported formats:**
- OSIS: `<transChange type="added">` tags
- USFX: `<add>` tags

**Example:** In Matthew 27:65 KJV, the word "it" is marked as added text:
> Pilate said unto them, Ye have a watch: go your way, make _it_ as sure as ye can.

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

Bible XML files in the example are from:
- [open-bibles](https://github.com/seven1m/open-bibles) GitHub repository
- [eBible.org](https://ebible.org/) - Free Bible translations in many languages
