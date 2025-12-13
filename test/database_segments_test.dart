import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Segments Persistence', () {
    late BibleRepository repository;
    final testDbName =
        'test_segments_${DateTime.now().millisecondsSinceEpoch}.db';

    tearDown(() async {
      try {
        await repository.close();
        final dbPath = await getDatabasesPath();
        final file = File('$dbPath/$testDbName');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('saves and retrieves verses with segments', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="John">
              <chapter osisID="John.11" n="11">
                <verse osisID="John.11.34" sID="John.11.34" n="34" />
                And said,
                <q who="Jesus" sID="John.11.34.q1" marker="" />Where have ye laid him?<q eID="John.11.34.q1" />
                They said unto him, Lord, come and see.
                <verse eID="John.11.34" />
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      repository = BibleRepository.fromString(
        xmlString: xml,
        format: 'OSIS',
      );

      await repository.initialize(testDbName);

      // Retrieve the verse
      final verses = await repository.getVerses('john', 11);

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.text, contains('And said'));
      expect(verse.text, contains('Where have ye laid him'));

      // Check segments were persisted
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(3));

      // First segment: "And said,"
      expect(verse.segments![0].text, 'And said,');
      expect(verse.segments![0].isJesus, isFalse);

      // Second segment: Jesus speaking
      expect(verse.segments![1].text, 'Where have ye laid him?');
      expect(verse.segments![1].isJesus, isTrue);
      expect(verse.segments![1].speaker, 'Jesus');

      // Third segment: Others speaking
      expect(
          verse.segments![2].text, 'They said unto him, Lord, come and see.');
      expect(verse.segments![2].isJesus, isFalse);

      expect(verse.hasJesusWords, isTrue);
    });

    test('saves and retrieves verses without segments', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="John">
              <chapter osisID="John.1" n="1">
                <verse osisID="John.1.1" n="1">In the beginning was the Word.</verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      repository = BibleRepository.fromString(
        xmlString: xml,
        format: 'OSIS',
      );

      await repository.initialize(testDbName);

      // Retrieve the verse
      final verses = await repository.getVerses('john', 1);

      expect(verses, hasLength(1));

      final verse = verses[0];
      expect(verse.text, contains('In the beginning was the Word'));
      expect(verse.segments, isNull);
      expect(verse.hasJesusWords, isFalse);
    });

    test('searchVerses returns verses with segments', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="John">
              <chapter osisID="John.14" n="14">
                <verse osisID="John.14.6" n="6">
                  <q who="Jesus">I am the way, the truth, and the life.</q>
                </verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      repository = BibleRepository.fromString(
        xmlString: xml,
        format: 'OSIS',
      );

      await repository.initialize(testDbName);

      // Search for verses
      final results = await repository.searchVerses('way');

      expect(results, hasLength(1));

      final verse = results[0];
      expect(verse.segments, isNotNull);
      expect(verse.segments, hasLength(1));
      expect(verse.segments![0].isJesus, isTrue);
      expect(verse.hasJesusWords, isTrue);
    });

    test('getVerse returns verse with segments', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="Matt">
              <chapter osisID="Matt.5" n="5">
                <verse osisID="Matt.5.3" n="3">
                  <q who="Jesus">Blessed are the poor in spirit.</q>
                </verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      repository = BibleRepository.fromString(
        xmlString: xml,
        format: 'OSIS',
      );

      await repository.initialize(testDbName);

      // Get specific verse
      final verse = await repository.getVerse('matt', 5, 3);

      expect(verse, isNotNull);
      expect(verse!.segments, isNotNull);
      expect(verse.segments, hasLength(1));
      expect(verse.segments![0].isJesus, isTrue);
      expect(verse.hasJesusWords, isTrue);
    });

    test('handles multiple verses with mixed segments', () async {
      final xml = '''
        <?xml version="1.0" encoding="UTF-8"?>
        <osis>
          <osisText>
            <div type="book" osisID="Matt">
              <chapter osisID="Matt.5" n="5">
                <verse osisID="Matt.5.1" n="1">
                  And seeing the multitudes, he went up into a mountain.
                </verse>
                <verse osisID="Matt.5.2" n="2">
                  And he opened his mouth, and taught them, saying,
                </verse>
                <verse osisID="Matt.5.3" n="3">
                  <q who="Jesus">Blessed are the poor in spirit.</q>
                </verse>
              </chapter>
            </div>
          </osisText>
        </osis>
      ''';

      repository = BibleRepository.fromString(
        xmlString: xml,
        format: 'OSIS',
      );

      await repository.initialize(testDbName);

      // Get all verses
      final verses = await repository.getVerses('matt', 5);

      expect(verses, hasLength(3));

      // First verse: no segments
      expect(verses[0].segments, isNull);
      expect(verses[0].hasJesusWords, isFalse);

      // Second verse: no segments
      expect(verses[1].segments, isNull);
      expect(verses[1].hasJesusWords, isFalse);

      // Third verse: has Jesus segment
      expect(verses[2].segments, isNotNull);
      expect(verses[2].segments, hasLength(1));
      expect(verses[2].hasJesusWords, isTrue);
    });
  });
}
