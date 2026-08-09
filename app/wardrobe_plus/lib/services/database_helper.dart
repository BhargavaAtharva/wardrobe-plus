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
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clothing (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        color TEXT,
        confidence REAL,
        imagePath TEXT,
        dateAdded TEXT NOT NULL
      )
    ''');
  }
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE clothing ADD COLUMN color TEXT');
  }
}

  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await instance.database;
    return await db.insert('clothing', item);
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await instance.database;
    return await db.query('clothing', orderBy: 'dateAdded DESC');
  }
}