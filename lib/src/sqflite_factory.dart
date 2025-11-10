// Platform-agnostic exports for selecting correct sqflite database factory
// The IO and web implementations will be resolved via conditional imports.
import 'sqflite_factory_io.dart'
    if (dart.library.html) 'sqflite_factory_web.dart' as impl;

export 'package:sqflite/sqflite.dart' show Database, ConflictAlgorithm, OpenDatabaseOptions, openDatabase;

/// The platform-specific database factory to use for opening databases.
get databaseFactoryPlatform => impl.databaseFactoryPlatform;

/// Returns the databases path for the platform.
Future<String> getDatabasesPathPlatform() => impl.getDatabasesPathPlatform();
