import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class MetadataCache {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'metadata_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE audio_files(path TEXT PRIMARY KEY, fileName TEXT, title TEXT, artist TEXT, album TEXT, duration REAL)',
        );
      },
    );
  }

  Future<void> insertFile(Map<String, dynamic> file) async {
    final db = await database;
    await db.insert(
      'audio_files',
      file,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFiles() async {
    final db = await database;
    return await db.query('audio_files');
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('audio_files');
  }
}
