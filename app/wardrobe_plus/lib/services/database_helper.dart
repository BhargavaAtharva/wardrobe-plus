import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'catalog.dart';
import 'formatters.dart';
import 'image_store.dart';

/// Local SQLite storage, one database file per profile, so each name that
/// signs in on this phone has its own closet and outfit history.
/// There is no cloud sync.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _pathOverride;
  static String? _profileId;

  /// The single shared database used before profiles had their own closets.
  static const legacyFileName = 'wardrobe.db';

  DatabaseHelper._init();

  static String fileNameFor(String profileId) => 'wardrobe_$profileId.db';

  /// Switch to a profile's database (opened lazily on next use).
  static Future<void> useProfile(String profileId) async {
    if (_profileId == profileId && _database != null) return;
    await _database?.close();
    _database = null;
    _profileId = profileId;
  }

  /// Close the current database (on sign out).
  static Future<void> close() async {
    await _database?.close();
    _database = null;
    _profileId = null;
  }

  /// Gives the old shared closet to [profileId] by renaming its file.
  /// Returns false if there is no old closet or the profile already has one.
  static Future<bool> claimLegacyDatabase(String profileId) async {
    if (_pathOverride != null) return false; // tests using their own file never touch real data
    final dir = await getDatabasesPath();
    final legacy = p.join(dir, legacyFileName);
    final target = p.join(dir, fileNameFor(profileId));
    if (!await databaseExists(legacy) || await databaseExists(target)) return false;
    await File(legacy).rename(target);
    return true;
  }

  /// For tests: use a specific database file (e.g. inMemoryDatabasePath).
  /// Pass null to go back to per-profile files.
  static Future<void> useDatabaseAt(String? path) async {
    await _database?.close();
    _database = null;
    _pathOverride = path;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = _pathOverride ??
        p.join(await getDatabasesPath(), _profileId == null ? legacyFileName : fileNameFor(_profileId!));
    _database = await openDatabase(path, version: 4, onCreate: _createDB, onUpgrade: _onUpgrade);
    return _database!;
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
    await _createOutfitLogs(db);
  }

  Future _createOutfitLogs(DatabaseExecutor db) => db.execute('''
        CREATE TABLE IF NOT EXISTS outfit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          itemIds TEXT NOT NULL,
          occasion TEXT
        )
      ''');

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE clothing ADD COLUMN color TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE clothing ADD COLUMN lastWorn TEXT');
      await db.execute('ALTER TABLE clothing ADD COLUMN wearCount INTEGER DEFAULT 0');
      await _createOutfitLogs(db);
    }
    if (oldVersion < 4) {
      // Store photo file names instead of full paths (full paths break when the
      // iOS app folder moves), and rename types from older model versions.
      final rows = await db.query('clothing', columns: ['id', 'imagePath', 'type']);
      for (final row in rows) {
        final stored = row['imagePath'] as String?;
        final type = row['type'] as String?;
        await db.update(
          'clothing',
          {
            if (stored != null && stored.isNotEmpty) 'imagePath': p.basename(stored),
            'type': Catalog.legacyTypes[type] ?? type,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  // ---------------- Clothing ----------------

  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await database;
    return db.insert('clothing', {'wearCount': 0, ...item});
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return db.query('clothing', orderBy: 'dateAdded DESC');
  }

  Future<Map<String, dynamic>?> getItem(int id) async {
    final db = await database;
    final rows = await db.query('clothing', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getRecentItems({int limit = 6}) async {
    final db = await database;
    return db.query('clothing', orderBy: 'dateAdded DESC', limit: limit);
  }

  /// Items not worn for [days]+ days. Never-worn items only count once they've
  /// been in the closet that long (a jacket added today isn't "forgotten").
  Future<List<Map<String, dynamic>>> getNotWornInAWhile({int days = 14, DateTime? now}) async {
    final db = await database;
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days)).toIso8601String();
    return db.query(
      'clothing',
      where: '(lastWorn IS NOT NULL AND lastWorn < ?) OR (lastWorn IS NULL AND dateAdded < ?)',
      whereArgs: [cutoff, cutoff],
      orderBy: 'COALESCE(lastWorn, dateAdded) ASC',
    );
  }

  Future<int> updateItem(int id, {String? type, String? color}) async {
    final db = await database;
    return db.update(
      'clothing',
      {if (type != null) 'type': type, if (color != null) 'color': color},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(int id) async {
    final item = await getItem(id);
    final db = await database;
    await db.delete('clothing', where: 'id = ?', whereArgs: [id]);
    await ImageStore.delete(item?['imagePath'] as String?);
  }

  Future<int> getTotalItems() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM clothing')) ?? 0;
  }

  // ---------------- Outfit history ----------------

  static List<int> parseIds(Object? stored) => (stored as String? ?? '')
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();

  static String outfitKey(List<int> ids) => ([...ids]..sort()).join('-');

  /// Logs today's outfit and updates each item's last-worn date and wear count.
  Future<int> logOutfit(List<int> itemIds, String occasion, {DateTime? when}) async {
    final db = await database;
    final date = (when ?? DateTime.now()).toIso8601String();
    return db.transaction((txn) async {
      final id = await txn.insert('outfit_logs', {
        'date': date,
        'itemIds': itemIds.join(','),
        'occasion': occasion,
      });
      await _recomputeWearStats(txn, itemIds);
      return id;
    });
  }

  /// True if this exact combination was already logged today.
  Future<bool> isLoggedToday(List<int> itemIds) async {
    final key = outfitKey(itemIds);
    final logs = await getOutfitLogs(since: startOfToday());
    return logs.any((log) => outfitKey(parseIds(log['itemIds'])) == key);
  }

  Future<List<Map<String, dynamic>>> getOutfitLogs({DateTime? since}) async {
    final db = await database;
    if (since == null) return db.query('outfit_logs', orderBy: 'date DESC');
    return db.query('outfit_logs',
        where: 'date >= ?', whereArgs: [since.toIso8601String()], orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getLatestOutfitToday() async {
    final logs = await getOutfitLogs(since: startOfToday());
    return logs.isEmpty ? null : logs.first;
  }

  /// Removes a history entry and corrects the worn dates/counts it affected.
  Future<void> deleteOutfitLog(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('outfit_logs', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      await txn.delete('outfit_logs', where: 'id = ?', whereArgs: [id]);
      await _recomputeWearStats(txn, parseIds(rows.first['itemIds']));
    });
  }

  Future<int> getTotalOutfitsLogged() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM outfit_logs')) ?? 0;
  }

  /// lastWorn/wearCount are derived from the history so they never drift.
  Future<void> _recomputeWearStats(DatabaseExecutor db, List<int> itemIds) async {
    for (final itemId in itemIds.toSet()) {
      final stats = await db.rawQuery(
        "SELECT COUNT(*) AS n, MAX(date) AS last FROM outfit_logs "
        "WHERE ',' || itemIds || ',' LIKE ?",
        ['%,$itemId,%'],
      );
      await db.update(
        'clothing',
        {'wearCount': stats.first['n'] as int? ?? 0, 'lastWorn': stats.first['last']},
        where: 'id = ?',
        whereArgs: [itemId],
      );
    }
  }

  // ---------------- Payloads for the server ----------------

  /// The closet in the shape the backend expects (dates in UTC).
  Future<List<Map<String, dynamic>>> itemsForServer() async => (await getAllItems())
      .map((i) => {
            'id': i['id'],
            'type': i['type'],
            'color': i['color'],
            'lastWorn': toUtcIso(i['lastWorn']),
            'wearCount': i['wearCount'],
            'imagePath': i['imagePath'],
          })
      .toList();

  /// The last 60 days of outfit history for repeat checks.
  Future<List<Map<String, dynamic>>> historyForServer() async =>
      (await getOutfitLogs(since: DateTime.now().subtract(const Duration(days: 60))))
          .map((h) => {'date': toUtcIso(h['date']), 'itemIds': parseIds(h['itemIds'])})
          .toList();

  static DateTime startOfToday([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
