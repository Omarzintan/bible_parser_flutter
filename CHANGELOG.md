## 0.2.1 - iOS Compatibility Fix

### Fixed
* **Critical iOS/Android compatibility issue** - Fixed SQLite error 14 (SQLITE_CANTOPEN) on iOS devices
* Platform detection now correctly uses native `sqflite` for iOS and Android instead of FFI
* Desktop platforms (Windows, Linux, macOS) continue to use `sqflite_common_ffi`

Fixes [#4](https://github.com/Omarzintan/bible_parser_flutter/issues/4)

## 0.2.0+1 - Example App Update

### Changed
* Updated example app to demonstrate red-letter Bible feature
* Added toggle switch to enable/disable red-letter display
* Jesus' words are now visually indicated with `[JESUS: ...]` markers

## 0.2.0 - Red-Letter Bible Support

### Added
* **Red-letter Bible support** for OSIS and USFX formats
  * New `TextSegment` class for styled text segments with attributes
  * `segments` field in `Verse` class for tracking speaker information and other attributes
  * Support for `<q who="Jesus">` tags in OSIS XML to identify Jesus' words
  * Support for `<wj>` (Words of Jesus) tags in USFX XML
  * `hasJesusWords` convenience getter on `Verse` class
* **Database persistence for segments**
  * New `verse_segments` table for storing text segments
  * Automatic segment loading when retrieving verses from database
  * Database version upgraded to 2 with migration support
* Extensible design allows future support for other XML styling tags (italics, notes, poetry, etc.)
* Exported parser classes (`OsisParser`, `UsfxParser`, `ZefaniaParser`) for direct use

### Changed
* OSIS parser now tracks quote tags and speaker attributes
* USFX parser now tracks wj tags and speaker attributes
* `Verse` class is backward compatible - existing code continues to work
* `BibleRepository` now persists and retrieves segments automatically
* Database schema updated with proper foreign key constraints and indexes

### Documentation
* Added comprehensive design document at `/doc/red-letter-bible-support.md`

### Testing
* Added 5 tests for OSIS red-letter parsing
* Added 5 tests for USFX red-letter parsing
* Added 5 tests for database segment persistence
* Added 29 tests for TextSegment serialization
* Added 1 test for cross-platform database support
* All 65 tests passing

## 0.1.0+4 - Bug Fixes in USFX parser

### Bug Fixes
* Fixed handling of footnotes and cross-references in USFX parser


## 0.1.0+3 - Bug fixes and performance improvements

### Bug Fixes
* Fixed USFX parser to properly handle chapter endings and ensure all chapters are added to books
* Fixed database handling in BibleRepository with proper null safety

### Improvements
* Enhanced BibleRepository with better database initialization and connection management
* Improved database operations with proper transaction handling and batch processing
* Added explicit database naming for better multi-Bible support
* Removed unused code and dependencies

## 0.1.0+2 - Bug fix and documentation updates

### Bug Fixes
* Fixed verse text concatenation with proper space handling and empty text checks

### Documentation
N/A

## 0.1.0+1 - Bug fix and documentation updates

### Bug Fixes
N/A

### Documentation
* Added note about tested XML file compatibility in README
* Removed unpublished status from README title

## 0.1.0 - Initial Release

### Features
* Support for multiple Bible XML formats:
  * OSIS (Open Scripture Information Standard)
  * USFX (Unified Scripture Format XML)
  * ZXBML (Zefania XML Bible Markup Language)
* Automatic format detection
* Memory-efficient XML parsing using proper async streams
* Production-ready with proper error handling and no debug statements

### Bible Repository Features
* SQLite database caching for improved performance
* Methods to retrieve books, chapters, and verses
* Verse retrieval by book and chapter
* Text search functionality across verses

### Example App
* Demonstrates both direct parsing and database approaches
* UI for selecting between different Bible formats
* Book and chapter selection interface
* Verse display with proper formatting and scrolling
* Search functionality for finding verses containing specific text
