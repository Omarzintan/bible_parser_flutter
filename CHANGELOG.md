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
