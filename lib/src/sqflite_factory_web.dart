// Web implementation using sqflite_common_ffi_web
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

DatabaseFactory get databaseFactoryPlatform => databaseFactoryFfiWeb;

Future<String> getDatabasesPathPlatform() async {
  // On web, databases path is not a real filesystem path. Use an empty string.
  return '';
}
