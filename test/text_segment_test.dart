import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('TextSegment', () {
    group('fromMap', () {
      test('creates segment from map with JSON string attributes', () {
        final map = {
          'text': 'Hello world',
          'attributes': jsonEncode({'speaker': 'Jesus', 'style': 'bold'}),
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Hello world');
        expect(segment.attributes, isNotNull);
        expect(segment.attributes!['speaker'], 'Jesus');
        expect(segment.attributes!['style'], 'bold');
        expect(segment.isJesus, isTrue);
      });

      test('creates segment from map with Map attributes', () {
        final map = {
          'text': 'Hello world',
          'attributes': {'speaker': 'Jesus', 'type': 'quote'},
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Hello world');
        expect(segment.attributes, isNotNull);
        expect(segment.attributes!['speaker'], 'Jesus');
        expect(segment.attributes!['type'], 'quote');
        expect(segment.isJesus, isTrue);
      });

      test('creates segment from map with null attributes', () {
        final map = {
          'text': 'Hello world',
          'attributes': null,
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Hello world');
        expect(segment.attributes, isNull);
        expect(segment.isJesus, isFalse);
      });

      test('creates segment from map without attributes key', () {
        final map = {
          'text': 'Hello world',
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Hello world');
        expect(segment.attributes, isNull);
      });

      test('handles invalid JSON gracefully', () {
        final map = {
          'text': 'Hello world',
          'attributes': 'not valid json {',
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Hello world');
        expect(segment.attributes, isNull);
      });

      test('handles non-Map JSON gracefully', () {
        final map = {
          'text': 'Hello world',
          'attributes': jsonEncode(['array', 'not', 'map']),
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Hello world');
        expect(segment.attributes, isNull);
      });

      test('parses complex attributes correctly', () {
        final map = {
          'text': 'Blessed are the poor in spirit',
          'attributes': jsonEncode({
            'speaker': 'Jesus',
            'style': 'italic',
            'type': 'beatitude',
            'poetry': 'true',
          }),
        };

        final segment = TextSegment.fromMap(map);

        expect(segment.text, 'Blessed are the poor in spirit');
        expect(segment.speaker, 'Jesus');
        expect(segment.style, 'italic');
        expect(segment.type, 'beatitude');
        expect(segment.isPoetry, isTrue);
        expect(segment.isJesus, isTrue);
      });
    });

    group('toMap', () {
      test('converts segment with attributes to map', () {
        final segment = TextSegment(
          text: 'Hello world',
          attributes: {'speaker': 'Jesus', 'style': 'bold'},
        );

        final map = segment.toMap();

        expect(map['text'], 'Hello world');
        expect(map['attributes'], isNotNull);
        expect(map['attributes'], isA<String>());

        // Verify JSON is valid and correct
        final decoded = jsonDecode(map['attributes'] as String);
        expect(decoded['speaker'], 'Jesus');
        expect(decoded['style'], 'bold');
      });

      test('converts segment without attributes to map', () {
        final segment = TextSegment(
          text: 'Hello world',
        );

        final map = segment.toMap();

        expect(map['text'], 'Hello world');
        expect(map['attributes'], isNull);
      });

      test('converts segment with empty attributes to map', () {
        final segment = TextSegment(
          text: 'Hello world',
          attributes: {},
        );

        final map = segment.toMap();

        expect(map['text'], 'Hello world');
        expect(map['attributes'], isNotNull);

        // Verify JSON is valid empty object
        final decoded = jsonDecode(map['attributes'] as String);
        expect(decoded, isEmpty);
      });

      test('handles special characters in attributes', () {
        final segment = TextSegment(
          text: 'Test text',
          attributes: {
            'speaker': 'Jesus',
            'note': 'Contains "quotes" and \'apostrophes\'',
          },
        );

        final map = segment.toMap();

        // Verify JSON is valid and special characters are escaped
        final decoded = jsonDecode(map['attributes'] as String);
        expect(decoded['speaker'], 'Jesus');
        expect(decoded['note'], 'Contains "quotes" and \'apostrophes\'');
      });
    });

    group('round-trip conversion', () {
      test('fromMap(toMap()) preserves segment data', () {
        final original = TextSegment(
          text: 'I am the way, the truth, and the life.',
          attributes: {
            'speaker': 'Jesus',
            'style': 'italic',
            'type': 'quote',
          },
        );

        final map = original.toMap();
        final restored = TextSegment.fromMap(map);

        expect(restored.text, original.text);
        expect(restored.attributes, original.attributes);
        expect(restored.speaker, original.speaker);
        expect(restored.style, original.style);
        expect(restored.type, original.type);
        expect(restored.isJesus, original.isJesus);
      });

      test('fromMap(toMap()) preserves segment without attributes', () {
        final original = TextSegment(
          text: 'In the beginning was the Word.',
        );

        final map = original.toMap();
        final restored = TextSegment.fromMap(map);

        expect(restored.text, original.text);
        expect(restored.attributes, original.attributes);
        expect(restored.isJesus, original.isJesus);
      });

      test('multiple round-trips preserve data', () {
        final original = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );

        var current = original;
        for (int i = 0; i < 5; i++) {
          final map = current.toMap();
          current = TextSegment.fromMap(map);
        }

        expect(current.text, original.text);
        expect(current.attributes, original.attributes);
        expect(current.isJesus, original.isJesus);
      });
    });

    group('attribute getters', () {
      test('speaker getter returns correct value', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );

        expect(segment.speaker, 'Jesus');
      });

      test('speaker getter returns null when not present', () {
        final segment = TextSegment(text: 'Test');

        expect(segment.speaker, isNull);
      });

      test('isJesus is case-insensitive', () {
        final segment1 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'jesus'},
        );
        final segment2 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'JESUS'},
        );
        final segment3 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'JeSuS'},
        );

        expect(segment1.isJesus, isTrue);
        expect(segment2.isJesus, isTrue);
        expect(segment3.isJesus, isTrue);
      });

      test('style getter returns correct value', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {'style': 'italic'},
        );

        expect(segment.style, 'italic');
      });

      test('type getter returns correct value', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {'type': 'note'},
        );

        expect(segment.type, 'note');
      });

      test('isPoetry returns true when poetry is true', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {'poetry': 'true'},
        );

        expect(segment.isPoetry, isTrue);
      });

      test('isPoetry returns false when poetry is false', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {'poetry': 'false'},
        );

        expect(segment.isPoetry, isFalse);
      });

      test('isPoetry returns false when poetry is not present', () {
        final segment = TextSegment(text: 'Test');

        expect(segment.isPoetry, isFalse);
      });
    });

    group('equality and hashCode', () {
      test('segments with same data are equal', () {
        final segment1 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );
        final segment2 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );

        expect(segment1, equals(segment2));
        expect(segment1.hashCode, equals(segment2.hashCode));
      });

      test('segments with different text are not equal', () {
        final segment1 = TextSegment(text: 'Test1');
        final segment2 = TextSegment(text: 'Test2');

        expect(segment1, isNot(equals(segment2)));
      });

      test('segments with different attributes are not equal', () {
        final segment1 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );
        final segment2 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Peter'},
        );

        expect(segment1, isNot(equals(segment2)));
      });

      test('segment with attributes not equal to segment without', () {
        final segment1 = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );
        final segment2 = TextSegment(text: 'Test');

        expect(segment1, isNot(equals(segment2)));
      });
    });

    group('toString', () {
      test('includes attributes when present', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {'speaker': 'Jesus'},
        );

        final str = segment.toString();

        expect(str, contains('Test'));
        expect(str, contains('speaker'));
        expect(str, contains('Jesus'));
      });

      test('excludes attributes when not present', () {
        final segment = TextSegment(text: 'Test');

        final str = segment.toString();

        expect(str, contains('Test'));
        expect(str, isNot(contains('attributes')));
      });

      test('excludes attributes when empty', () {
        final segment = TextSegment(
          text: 'Test',
          attributes: {},
        );

        final str = segment.toString();

        expect(str, contains('Test'));
        expect(str, isNot(contains('attributes')));
      });
    });
  });
}
