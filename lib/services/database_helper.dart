import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/link.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;

class DatabaseHelper {
  // Create a singleton instance of DatabaseHelper
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  // Private constructor
  DatabaseHelper._internal();

  // Factory constructor
  factory DatabaseHelper() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'links.db');
    
    // Instead of deleting database, handle migration properly
    return await openDatabase(
      path,
      version: 2, // Increment version to handle migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE links(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        tags TEXT,
        createdAt TEXT,
        isArchived INTEGER DEFAULT 0,
        isDeleted INTEGER DEFAULT 0,
        cached_content TEXT,
        cached_summary TEXT,
        isPinned INTEGER NOT NULL DEFAULT 0,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        cache_updated INTEGER
      )
    ''');
    debugPrint('Database created with all required columns');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add the caching columns if upgrading from version 1
      try {
        await db.execute('ALTER TABLE links ADD COLUMN cached_content TEXT;');
        await db.execute('ALTER TABLE links ADD COLUMN cached_summary TEXT;');
        await db.execute('ALTER TABLE links ADD COLUMN cache_updated INTEGER;');
        debugPrint('Added cache columns during upgrade');
      } catch (e) {
        debugPrint('Error during database upgrade: $e');
      }
    }
  }

  Future<Link> create(Link link) async {
    final db = await database;
    
    // Create a clean map without null values for cached fields
    final Map<String, dynamic> linkMap = {
      'url': link.url,
      'title': link.title,
      'description': link.description,
      'tags': link.tags,
      'createdAt': link.createdAt.toIso8601String(),
      'isArchived': link.isArchived ? 1 : 0,
      'isDeleted': link.isDeleted ? 1 : 0,
    };
    
    // Only add cache fields if they have values
    if (link.cachedContent != null) {
      linkMap['cached_content'] = link.cachedContent;
    }
    if (link.cachedSummary != null) {
      linkMap['cached_summary'] = link.cachedSummary;
    }
    
    final id = await db.insert('links', linkMap);
    debugPrint('Link inserted with ID: $id');
    return link.id == null ? Link.fromMap({...linkMap, 'id': id}) : link;
  }

  Future<List<Link>> getAllLinks({bool archived = false, bool deleted = false}) async {
    final db = await database;
    final result = await db.query(
      'links',
      where: deleted ? 'isDeleted = 1' : 'isArchived = ? AND isDeleted = 0',
      whereArgs: deleted ? [] : [archived ? 1 : 0],
      orderBy: 'isPinned DESC, createdAt DESC', // Show pinned items first
    );
    return result.map((json) => Link.fromMap(json)).toList();
  }

  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      'links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateArchiveStatus(int id, bool isArchived) async {
    final db = await database;
    return await db.update(
      'links',
      {'isArchived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleArchive(int id, bool isArchived) async {
    final db = await database;
    return await db.update(
      'links',
      {'isArchived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDelete(int id) async {
    final db = await database;
    return await db.update(
      'links',
      {'isDeleted': 1, 'isArchived': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restore(int id) async {
    final db = await database;
    return await db.update(
      'links',
      {'isDeleted': 0, 'isArchived': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> permanentDelete(int id) async {
    // First clear the cache
    await clearCacheForLink(id);
    
    // Then delete from database
    final db = await database;
    return await db.delete(
      'links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get cache directory path
  Future<String> get _cachePath async {
    final directory = await getApplicationCacheDirectory();
    final path = join(directory.path, 'link_previews');
    // Create the directory if it doesn't exist
    await Directory(path).create(recursive: true);
    return path;
  }
  
  // Clear cache for a specific link
  Future<void> clearCacheForLink(int id) async {
    try {
      final cacheDir = await _cachePath;
      final file = File('$cacheDir/link_$id.cache');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail on cache deletion errors
      print('Failed to clear cache: $e');
    }
  }
  
  // Clear all caches
  Future<void> clearAllCaches() async {
    try {
      final cacheDir = await _cachePath;
      final directory = Directory(cacheDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('Failed to clear caches: $e');
    }
  }
  
  // New method to permanently delete multiple items
  Future<void> permanentDeleteMultiple(List<int> ids) async {
    for (final id in ids) {
      await clearCacheForLink(id);
      
      final db = await database;
      await db.delete(
        'links',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> updateLinkCache(int linkId, String? content, String? summary) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    try {
      await db.update(
        'links',
        {
          'cached_content': content,
          'cached_summary': summary,
          'cache_updated': timestamp,
        },
        where: 'id = ?',
        whereArgs: [linkId],
      );
    } catch (e) {
      debugPrint('Database update error: $e');
      // Try migration if columns don't exist
      await _onUpgrade(db, 1, 2);
      // Retry update after migration
      await db.update(
        'links',
        {
          'cached_content': content,
          'cached_summary': summary,
          'cache_updated': timestamp,
        },
        where: 'id = ?',
        whereArgs: [linkId],
      );
    }
  }
  
  // New method to check if cache is fresh (within 7 days)
  Future<bool> isCacheFresh(int linkId) async {
    final db = await database;
    final result = await db.query(
      'links',
      columns: ['cache_updated'],
      where: 'id = ?',
      whereArgs: [linkId],
    );
    
    if (result.isEmpty || result[0]['cache_updated'] == null) {
      return false;
    }
    
    final cacheUpdated = DateTime.parse(result[0]['cache_updated'] as String);
    final now = DateTime.now();
    final difference = now.difference(cacheUpdated);
    
    // Cache is fresh if it's less than 7 days old
    return difference.inDays < 7;
  }

  // Modify purgeCacheForUrl to properly handle cache fields
  Future<void> purgeCacheForUrl(String url) async {
    final db = await database;
    
    // Find all links with this URL and clear their cached content
    await db.update(
      'links',
      {
        'cached_content': null,
        'cached_summary': null,
        'cache_updated': null,
      },
      where: 'url = ?',
      whereArgs: [url],
    );
  }

  Future<void> updatePinStatus(int id, bool isPinned) async {
    final db = await database;
    await db.update(
      'links',
      {'isPinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateFavoriteStatus(int id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'links',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Link>> getFavoriteLinks() async {
    final db = await database;
    final result = await db.query(
      'links',
      where: 'isFavorite = 1 AND isDeleted = 0',
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Link.fromMap(json)).toList();
  }

  void insertLink(Link newLink) {}
}
