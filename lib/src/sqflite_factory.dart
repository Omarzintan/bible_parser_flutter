// Platform-agnostic exports for selecting correct sqflite database factory
// The IO implementation will be used for mobile and desktop platforms.
import 'sqflite_factory_io.dart' as impl;

export 'package:sqflite/sqflite.dart'
    show Database, ConflictAlgorithm, OpenDatabaseOptions, openDatabase;

/// The platform-specific database factory to use for opening databases.
get databaseFactoryPlatform => impl.databaseFactoryPlatform;

/// Returns the databases path for the platform.
Future<String> getDatabasesPathPlatform() => impl.getDatabasesPathPlatform();
