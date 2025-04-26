import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'database_helper.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'metadata.db');
    
    // This is a separate database for metadata only
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE metadata_cache(
        url TEXT PRIMARY KEY,
        content TEXT,
        summary TEXT,
        timestamp INTEGER,
        expires_at INTEGER
      )
    ''');
  }

  Future<void> updateLinkCache(String linkId, String? content, String? summary) async {
    try {
      // Redirect to DatabaseHelper
      await DatabaseHelper().updateLinkCache(int.parse(linkId), content, summary);
    } catch (e) {
      debugPrint('Error updating link cache: $e');
    }
  }
}