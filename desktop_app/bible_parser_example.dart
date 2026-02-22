import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bible_parser_flutter/bible_parser_flutter.dart';

void main() {
  runApp(const BibleParserExampleApp());
}

class BibleParserExampleApp extends StatelessWidget {
  const BibleParserExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible Parser Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BibleParserExampleScreen(),
    );
  }
}

class BibleParserExampleScreen extends StatefulWidget {
  const BibleParserExampleScreen({super.key});

  @override
  State<BibleParserExampleScreen> createState() => _BibleParserExampleScreenState();
}

class _BibleParserExampleScreenState extends State<BibleParserExampleScreen> {
  final String xmlPath = 'assets/bible.xml'; // Example path to a Bible XML file
  bool isLoading = false;
  String result = '';
  BibleRepository? repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible Parser Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _parseDirectly,
              child: const Text('Parse Directly'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeDatabase,
              child: const Text('Initialize Database'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: repository != null ? _searchVerses : null,
              child: const Text('Search for "love"'),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Text(result),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Example of direct parsing approach
  Future<void> _parseDirectly() async {
    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      // Create a parser
      final parser = BibleParser(File(xmlPath));
      
      // Get the first 5 verses
      final verses = <Verse>[];
      int count = 0;
      
      await for (final verse in parser.verses) {
        verses.add(verse);
        count++;
        if (count >= 5) break;
      }
      
      setState(() {
        result = 'Direct Parsing Results:\n\n' +
            verses.map((v) => '${v.bookId} ${v.chapterNum}:${v.num} - ${v.text}').join('\n\n');
      });
    } catch (e) {
      setState(() {
        result = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Example of database approach
  Future<void> _initializeDatabase() async {
    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      // Create a repository
      repository = BibleRepository(xmlPath: xmlPath);
      final databaseName = '${xmlPath.split('/').last.split('.').first}.db';
      
      // Initialize the database (this will parse the XML and store it in the database)
      final stopwatch = Stopwatch()..start();
      await repository!.initialize(databaseName);
      stopwatch.stop();
      
      // Get all books
      final books = await repository!.getBooks();
      
      setState(() {
        result = 'Database Initialized in ${stopwatch.elapsedMilliseconds}ms\n\n' +
            'Books:\n' +
            books.map((b) => '${b.num}. ${b.title} (${b.id})').join('\n');
      });
    } catch (e) {
      setState(() {
        result = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Example of searching verses using the database
  Future<void> _searchVerses() async {
    if (repository == null) return;
    
    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      // Search for verses containing "love"
      final stopwatch = Stopwatch()..start();
      final verses = await repository!.searchVerses('love');
      stopwatch.stop();
      
      setState(() {
        result = 'Search completed in ${stopwatch.elapsedMilliseconds}ms\n\n' +
            'Found ${verses.length} verses containing "love":\n\n' +
            verses.take(10).map((v) => '${v.bookId} ${v.chapterNum}:${v.num} - ${v.text}').join('\n\n') +
            (verses.length > 10 ? '\n\n... and ${verses.length - 10} more' : '');
      });
    } catch (e) {
      setState(() {
        result = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
