// IO/desktop implementation using sqflite_common_ffi
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory get databaseFactoryPlatform {
  // Initialize ffi for desktop platforms
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<String> getDatabasesPathPlatform() async {
  // Use getDatabasesPath from sqflite if available; otherwise fallback to current dir
  try {
    final path = await databaseFactoryPlatform.getDatabasesPath();
    return path;
  } catch (_) {
    return Directory.current.path;
  }
}
