import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wardrobe.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clothing (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        color TEXT,
        confidence REAL,
        imagePath TEXT,
        dateAdded TEXT NOT NULL,
        lastWorn TEXT,
        wearCount INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE outfit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        itemIds TEXT NOT NULL,
        occasion TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE clothing ADD COLUMN color TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE clothing ADD COLUMN lastWorn TEXT');
      await db.execute('ALTER TABLE clothing ADD COLUMN wearCount INTEGER DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS outfit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          itemIds TEXT NOT NULL,
          occasion TEXT
        )
      ''');
    }
  }

  // Clothing methods
  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await instance.database;
    return await db.insert('clothing', item);
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await instance.database;
    return await db.query('clothing', orderBy: 'dateAdded DESC');
  }

  Future<List<Map<String, dynamic>>> getRecentItems({int limit = 6}) async {
    final db = await instance.database;
    return await db.query('clothing', orderBy: 'dateAdded DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> getNotWornRecently({int days = 7}) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return await db.query(
      'clothing',
      where: 'lastWorn IS NULL OR lastWorn < ?',
      whereArgs: [cutoff],
      orderBy: 'lastWorn ASC',
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('clothing', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateItemType(int id, String newType) async {
    final db = await instance.database;
    return await db.update(
      'clothing',
      {'type': newType},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateItemColor(int id, String newColor) async {
    final db = await instance.database;
    return await db.update(
      'clothing',
      {'color': newColor},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsWorn(List<int> itemIds) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    for (final id in itemIds) {
      await db.rawUpdate(
        'UPDATE clothing SET lastWorn = ?, wearCount = wearCount + 1 WHERE id = ?',
        [now, id],
      );
    }
  }

  // Outfit log methods
  Future<int> logOutfit(List<int> itemIds, String occasion) async {
    final db = await instance.database;
    return await db.insert('outfit_logs', {
      'date': DateTime.now().toIso8601String(),
      'itemIds': itemIds.join(','),
      'occasion': occasion,
    });
  }

  Future<List<Map<String, dynamic>>> getOutfitLogs() async {
    final db = await instance.database;
    return await db.query('outfit_logs', orderBy: 'date DESC');
  }

  Future<int> getTotalItems() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM clothing');
    return result.first['count'] as int;
  }

  Future<int> getTotalOutfitsLogged() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM outfit_logs');
    return result.first['count'] as int;
  }
}