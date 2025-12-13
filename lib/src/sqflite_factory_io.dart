// IO/desktop implementation with platform-specific SQLite handling
import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite_native;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory get databaseFactoryPlatform {
  // Use native sqflite for iOS and Android
  if (Platform.isIOS || Platform.isAndroid) {
    return sqflite_native.databaseFactory;
  }

  // Use FFI for desktop platforms (Windows, Linux, macOS)
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<String> getDatabasesPathPlatform() async {
  // Use native sqflite path for iOS and Android
  if (Platform.isIOS || Platform.isAndroid) {
    return await sqflite_native.getDatabasesPath();
  }

  // Use FFI path for desktop platforms
  try {
    final path = await databaseFactoryPlatform.getDatabasesPath();
    return path;
  } catch (_) {
    return Directory.current.path;
  }
}
