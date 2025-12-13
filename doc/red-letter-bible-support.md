# Red-Letter Bible Support

## Overview

This document outlines the design for implementing red-letter Bible support (and other text styling features) in the bible_parser_flutter package. The design allows users to differentiate Jesus' words from other text, with extensibility for future styling needs.

## Design Goals

1. **Backward Compatibility** - Existing code continues to work without changes
2. **Opt-in Complexity** - Users who don't need styling can ignore it
3. **Extensibility** - Easy to add support for other XML tags and attributes
4. **No Breaking Changes** - The `text` field remains as the full verse text

## Data Model

### TextSegment Class

```dart
class TextSegment {
  final String text;
  final Map<String, String>? attributes;  // Flexible key-value pairs
  
  // Convenience getters
  String? get speaker => attributes?['speaker'];
  bool get isJesus => speaker?.toLowerCase() == 'jesus';
  
  // Easy to add more getters for other attributes
  String? get style => attributes?['style'];  // e.g., for <hi> tags
  String? get type => attributes?['type'];    // e.g., for <note> tags
  bool get isPoetry => attributes?['poetry'] == 'true';
}
```

### Updated Verse Class

```dart
class Verse {
  final int num;
  final int chapterNum;
  final String text;  // Full verse text (always present)
  final String bookId;
  
  // New field for styled text support
  final List<TextSegment>? segments;  // Optional, only when styling info exists
  
  // Convenience getter
  bool get hasJesusWords => segments?.any((s) => s.isJesus) ?? false;
}
```

## OSIS XML Example

```xml
<verse osisID="John.11.34" sID="John.11.34.seID.35235" n="34" />
And said,
<q who="Jesus" sID="John.11.34.seID.35236" marker="" />
Where have ye laid him?
<q eID="John.11.34.seID.35236" />
They said unto him, Lord, come and see.
<verse eID="John.11.34.seID.35235" />
```

## Parser Implementation

### Parsing State

Add to the OSIS parser's state tracking:

```dart
// Current segment tracking
List<TextSegment> currentSegments = [];
StringBuffer currentSegmentText = StringBuffer();
Map<String, String>? currentAttributes;
```

### Event Handling for `<q>` Tags

```dart
// Start of quote tag
if (event.name == 'q' && !event.attributes.any((attr) => attr.name == 'eID')) {
  // Save current segment before starting new one
  if (currentSegmentText.isNotEmpty) {
    currentSegments.add(TextSegment(
      text: currentSegmentText.toString().trim(),
      attributes: currentAttributes,
    ));
    currentSegmentText.clear();
  }
  
  // Extract attributes from <q> tag
  Map<String, String> attrs = {};
  for (var attr in event.attributes) {
    if (attr.name == 'who') {
      attrs['speaker'] = attr.value;
    }
    // Can add more attributes as needed
  }
  currentAttributes = attrs.isNotEmpty ? attrs : null;
}

// End of quote tag
else if (event.name == 'q' && event.attributes.any((attr) => attr.name == 'eID')) {
  // Save current segment and reset
  if (currentSegmentText.isNotEmpty) {
    currentSegments.add(TextSegment(
      text: currentSegmentText.toString().trim(),
      attributes: currentAttributes,
    ));
    currentSegmentText.clear();
  }
  currentAttributes = null;
}
```

### Text Collection

```dart
else if (event is XmlTextEvent && currentVerse != null) {
  final trimmedText = event.value.trim();
  if (trimmedText.isNotEmpty) {
    // Add to current segment
    currentSegmentText.write(trimmedText);
    currentSegmentText.write(' ');
    
    // Also append to full verse text
    final newText = [currentVerse.text, trimmedText].join(' ');
    currentVerse = Verse(
      num: currentVerse.num,
      chapterNum: currentVerse.chapterNum,
      text: newText,
      bookId: currentVerse.bookId,
      segments: currentSegments.isNotEmpty ? List.from(currentSegments) : null,
    );
  }
}
```

## Usage Patterns

### Standard Usage (No Styling)

Users who don't need red-letter support continue using the `text` field:

```dart
// Simple text display
Text(verse.text)
```

### Red-Letter Usage

Users who want red-letter support check for segments:

```dart
Widget buildVerseText(Verse verse) {
  if (verse.segments != null) {
    // Use segments for styled text
    return RichText(
      text: TextSpan(
        children: verse.segments!.map((segment) => 
          TextSpan(
            text: segment.text,
            style: TextStyle(
              color: segment.isJesus ? Colors.red : Colors.black,
            ),
          )
        ).toList(),
      ),
    );
  } else {
    // Fallback to plain text
    return Text(verse.text);
  }
}
```

### Checking for Jesus' Words

```dart
if (verse.hasJesusWords) {
  // Special handling for verses with Jesus speaking
}
```

## Future Extensions

The flexible `attributes` map allows for easy extension to support other XML tags:

### Italics/Emphasis (`<hi>` tags)

```xml
<hi type="italic">supplied words</hi>
```

```dart
if (segment.style == 'italic') {
  style = TextStyle(fontStyle: FontStyle.italic);
}
```

### Footnotes/Notes (`<note>` tags)

```xml
<note type="study">Historical context...</note>
```

```dart
if (segment.type == 'note') {
  // Display as footnote or tooltip
}
```

### Poetry/Selah (`<l>` tags)

```xml
<l level="1">Blessed is the man</l>
```

```dart
if (segment.isPoetry) {
  // Apply poetry formatting
  int level = int.parse(segment.attributes?['level'] ?? '0');
  // Indent based on level
}
```

### Divine Names (Tetragrammaton)

```xml
<divineName>LORD</divineName>
```

```dart
if (segment.attributes?['divine'] == 'true') {
  style = TextStyle(fontVariant: FontVariant.smallCaps);
}
```

## Database Considerations

For the database-backed approach (`BibleRepository`), the segments need to be serialized:

### Storage Options

1. **JSON Column** - Store segments as JSON in a text column
2. **Separate Table** - Create a `verse_segments` table with foreign key to verses
3. **Hybrid** - Store full text in verses table, segments in separate table (recommended)

### Recommended Schema

```sql
-- Existing verses table remains unchanged
CREATE TABLE verses (
  id INTEGER PRIMARY KEY,
  book_id TEXT NOT NULL,
  chapter_num INTEGER NOT NULL,
  verse_num INTEGER NOT NULL,
  text TEXT NOT NULL
);

-- New table for segments (optional, only populated if segments exist)
CREATE TABLE verse_segments (
  id INTEGER PRIMARY KEY,
  verse_id INTEGER NOT NULL,
  segment_order INTEGER NOT NULL,
  text TEXT NOT NULL,
  attributes TEXT,  -- JSON string of attributes
  FOREIGN KEY (verse_id) REFERENCES verses(id)
);
```

## Implementation Checklist

- [ ] Create `TextSegment` class
- [ ] Update `Verse` class with `segments` field
- [ ] Modify `OsisParser` to track `<q>` tags
- [ ] Update database schema for segment storage
- [ ] Update `BibleRepository` to handle segments
- [ ] Add tests for red-letter parsing
- [ ] Update documentation and examples
- [ ] Consider adding support for other parsers (USFX, Zefania)

## Testing

### Test Cases

1. Verses with no Jesus quotes (segments should be null)
2. Verses with only Jesus speaking (single segment with speaker="Jesus")
3. Verses with mixed speech (multiple segments)
4. Verses with nested tags
5. Database round-trip (save and retrieve segments)

### Example Test Data

```dart
test('parses Jesus quotes correctly', () async {
  final xml = '''
    <verse osisID="John.11.34" n="34">
      And said,
      <q who="Jesus">Where have ye laid him?</q>
      They said unto him, Lord, come and see.
    </verse>
  ''';
  
  final verse = await parseVerse(xml);
  
  expect(verse.text, contains('Where have ye laid him?'));
  expect(verse.segments, hasLength(3));
  expect(verse.segments![1].isJesus, isTrue);
  expect(verse.hasJesusWords, isTrue);
});
```

## Migration Path

1. **Phase 1** - Add `TextSegment` class and update `Verse` model (non-breaking)
2. **Phase 2** - Update OSIS parser to populate segments
3. **Phase 3** - Update database schema and repository
4. **Phase 4** - Add example implementation in example app
5. **Phase 5** - Document usage patterns and publish

## Notes

- The `text` field always contains the complete verse text, ensuring backward compatibility
- The `segments` field is optional and only populated when styling information exists
- The design is format-agnostic and can be extended to USFX and Zefania parsers
- Performance impact should be minimal as segments are only created when needed
