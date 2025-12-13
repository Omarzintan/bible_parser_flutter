import 'package:test/test.dart';
import 'package:bible_parser_flutter/src/bible_repository.dart';

const String sampleOsisXml = '''
<osis>
  <osisText osisIDWork="Bible" xml:lang="en">
    <div type="book" osisID="Gen">
      <chapter osisID="Gen.1">
        <verse osisID="Gen.1.1">In the beginning God created the heaven and the earth.</verse>
        <verse osisID="Gen.1.2">And the earth was without form, and void; and darkness was upon the face of the deep.</verse>
      </chapter>
    </div>
  </osisText>
</osis>
''';

void main() {
  test('BibleRepository initializes and reads books/verses (FFI)', () async {
    final repo = BibleRepository.fromString(xmlString: sampleOsisXml, format: 'osis');
    final ok = await repo.initialize('test_bible_ffi.db');
    expect(ok, isTrue);
    final books = await repo.getBooks();
    expect(books, isNotEmpty);
    final verses = await repo.getVerses(books.first.id, 1);
    expect(verses.length, 2);
    expect(verses.first.text, contains('In the beginning'));
    await repo.close();
  });
}
