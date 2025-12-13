# TransChange Support for Added/Italicized Text

## Overview

The `bible_parser_flutter` package now supports tracking text marked with the `<transChange>` tag in OSIS format. This feature allows Bible apps to identify and style translator additions, which are typically italicized in printed Bibles.

## What is TransChange?

In Bible translations, translators sometimes add words that aren't directly in the original text but are necessary for clarity in the target language. These additions are traditionally marked in italics. The OSIS format uses the `<transChange type="added">` tag to identify such text.

### Example from KJV Matthew 27:65

```xml
<verse osisID="Matt.27.65" sID="Matt.27.65" n="65" />
Pilate said unto them, Ye have a watch: go your way, make
<transChange type="added">it</transChange> as sure as ye can.
<verse eID="Matt.27.65" />
```

In this verse, the word "it" is a translator addition and would typically be italicized:
> Pilate said unto them, Ye have a watch: go your way, make _it_ as sure as ye can.

## Implementation

### TextSegment Class

The `TextSegment` class now includes:

```dart
/// Gets the transChange attribute if present.
String? get transChange => attributes?['transChange'];

/// Returns true if this segment is added text (typically italicized in Bibles).
bool get isAdded => transChange?.toLowerCase() == 'added';
```

### OSIS Parser

The OSIS parser has been updated to:
1. Detect `<transChange>` start tags and extract the `type` attribute
2. Track text within transChange tags as separate segments
3. Handle the end of transChange tags properly
4. Preserve other attributes (like `speaker` for Jesus' words) when transChange is present

## Usage

### Basic Usage

```dart
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

// Get a verse
final repository = BibleRepository.fromString(xmlString: osisXml);
await repository.initialize('bible.db');
final verse = await repository.getVerse('Matt', 27, 65);

// Check for added text
if (verse.segments != null) {
  for (final segment in verse.segments!) {
    if (segment.isAdded) {
      // Render in italics
      print('Italic: ${segment.text}');
    } else {
      print('Normal: ${segment.text}');
    }
  }
}
```

### Flutter Widget Example

```dart
Widget buildVerseText(Verse verse) {
  if (verse.segments == null || verse.segments!.isEmpty) {
    return Text(verse.text);
  }

  final spans = <TextSpan>[];
  for (final segment in verse.segments!) {
    spans.add(TextSpan(
      text: segment.text,
      style: segment.isAdded
          ? TextStyle(fontStyle: FontStyle.italic)
          : null,
    ));
  }

  return Text.rich(TextSpan(children: spans));
}
```

### Combined with Red-Letter Support

You can combine transChange support with red-letter Bible features:

```dart
Widget buildStyledVerseText(Verse verse) {
  if (verse.segments == null || verse.segments!.isEmpty) {
    return Text(verse.text);
  }

  final spans = <TextSpan>[];
  for (final segment in verse.segments!) {
    TextStyle? style;
    
    if (segment.isJesus && segment.isAdded) {
      // Red italic text (Jesus' words that are translator additions)
      style = TextStyle(
        color: Colors.red.shade700,
        fontStyle: FontStyle.italic,
      );
    } else if (segment.isJesus) {
      // Red text (Jesus' words)
      style = TextStyle(color: Colors.red.shade700);
    } else if (segment.isAdded) {
      // Italic text (translator additions)
      style = TextStyle(fontStyle: FontStyle.italic);
    }

    spans.add(TextSpan(text: segment.text, style: style));
  }

  return Text.rich(TextSpan(children: spans));
}
```

## Supported Formats

Currently, transChange support is implemented for:
- **OSIS**: `<transChange type="added">` tags

Future support may be added for other formats as needed.

## Database Persistence

TransChange attributes are automatically:
- Saved to the database when parsing and initializing
- Loaded from the database when retrieving verses
- Stored in the `verse_segments` table with other segment attributes

No additional configuration is required.

## Testing

The implementation includes comprehensive tests:
- Parsing transChange tags from OSIS XML
- Handling transChange within Jesus' quotes
- Preserving full verse text while tracking segments
- TextSegment.isAdded getter behavior

Run tests with:
```bash
flutter test test/trans_change_test.dart
```

## Technical Details

### Attribute Storage

The `transChange` type is stored in the segment's `attributes` map:
```dart
{
  'transChange': 'added'
}
```

### Segment Tracking

When the parser encounters a `<transChange>` tag:
1. The current segment (if any) is saved
2. A new segment begins with the `transChange` attribute
3. Text within the tag is collected
4. When the closing `</transChange>` tag is found, the segment is saved and the attribute is removed

### Compatibility

This feature is:
- ✅ Backward compatible - existing code continues to work
- ✅ Optional - verses without transChange tags work normally
- ✅ Extensible - can be combined with other segment attributes
- ✅ Cross-platform - works on all supported platforms

## Future Enhancements

Potential future additions:
- Support for other transChange types (e.g., `type="tenseChange"`)
- Support for transChange in USFX format
- Additional styling attributes from OSIS tags
