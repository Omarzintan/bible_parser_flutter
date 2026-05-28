import 'package:flutter_test/flutter_test.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  group('USFX Toc Parsing', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <toc level="1">The First Book of Moses, Commonly Called Genesis</toc>
    <toc level="2">Genesis</toc>
    <toc level="3">Gen</toc>
    <c id="1"/>
    <v id="1"/>In the beginning God created the heavens and the earth.<ve/>
  </book>
</usfx>
''';

    test('parses all three toc levels into book fields', () async {
      final parser = UsfxParser(xml);
      final books = await parser.parseBooks().toList();

      expect(books, hasLength(1));
      final book = books[0];

      expect(book.longTitle,
          'The First Book of Moses, Commonly Called Genesis');
      expect(book.shortTitle, 'Genesis');
      expect(book.abbreviation, 'Gen');
    });

    test('title falls back to built-in name when toc is absent', () async {
      const xmlNoToc = '''
<?xml version="1.0" encoding="UTF-8"?>
<usfx>
  <book id="GEN">
    <c id="1"/>
    <v id="1"/>In the beginning God created the heavens and the earth.<ve/>
  </book>
</usfx>
''';
      final parser = UsfxParser(xmlNoToc);
      final books = await parser.parseBooks().toList();

      expect(books, hasLength(1));
      final book = books[0];

      expect(book.title, 'Genesis');
      expect(book.longTitle, isNull);
      expect(book.shortTitle, isNull);
      expect(book.abbreviation, isNull);
    });
  });
}
