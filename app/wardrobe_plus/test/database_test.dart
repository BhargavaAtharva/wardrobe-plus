import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wardrobe_plus/services/database_helper.dart';
import 'package:wardrobe_plus/services/image_store.dart';

void main() {
  late Directory tmp;
  final db = DatabaseHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wardrobe_test');
    ImageStore.useDirectory(tmp);
    await DatabaseHelper.useDatabaseAt('${tmp.path}/wardrobe.db');
  });

  tearDown(() async {
    await DatabaseHelper.useDatabaseAt(inMemoryDatabasePath);
    await tmp.delete(recursive: true);
  });

  Future<int> addItem(String type, {String color = 'black', DateTime? added}) => db.insertItem({
        'type': type,
        'color': color,
        'imagePath': 'x.jpg',
        'dateAdded': (added ?? DateTime.now()).toIso8601String(),
      });

  test('upgrading from v3 keeps items, stores file names and renames old types', () async {
    final path = '${tmp.path}/legacy.db';
    final legacy = await openDatabase(path, version: 3, onCreate: (d, v) async {
      await d.execute('CREATE TABLE clothing (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, color TEXT, '
          'confidence REAL, imagePath TEXT, dateAdded TEXT NOT NULL, lastWorn TEXT, wearCount INTEGER DEFAULT 0)');
      await d.execute('CREATE TABLE outfit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, itemIds TEXT NOT NULL, occasion TEXT)');
    });
    await legacy.insert('clothing', {
      'type': 'Jeans',
      'color': 'blue',
      'imagePath': '/var/mobile/Containers/Data/Application/OLD/Documents/1712.jpg',
      'dateAdded': '2026-08-01T10:00:00.000',
    });
    await legacy.close();

    await DatabaseHelper.useDatabaseAt(path);
    final items = await db.getAllItems();
    expect(items, hasLength(1));
    expect(items.first['imagePath'], '1712.jpg');
    expect(items.first['type'], 'Pants');
  });

  test('logging an outfit updates last worn and wear count', () async {
    final shirt = await addItem('Shirts');
    final pants = await addItem('Pants');
    await db.logOutfit([shirt, pants], 'Office', when: DateTime(2026, 10, 1));
    await db.logOutfit([shirt], 'Casual', when: DateTime(2026, 10, 5));

    final s = await db.getItem(shirt);
    final p = await db.getItem(pants);
    expect(s!['wearCount'], 2);
    expect(s['lastWorn'], DateTime(2026, 10, 5).toIso8601String());
    expect(p!['wearCount'], 1);
  });

  test('deleting a history entry recomputes the stats', () async {
    final shirt = await addItem('Shirts');
    await db.logOutfit([shirt], 'Office', when: DateTime(2026, 10, 1));
    final later = await db.logOutfit([shirt], 'Office', when: DateTime(2026, 10, 5));
    await db.deleteOutfitLog(later);

    final s = await db.getItem(shirt);
    expect(s!['wearCount'], 1);
    expect(s['lastWorn'], DateTime(2026, 10, 1).toIso8601String());
  });

  test('item ids do not match by prefix (1 vs 11)', () async {
    for (var i = 0; i < 11; i++) {
      await addItem('Tshirts');
    }
    await db.logOutfit([11], 'Casual');
    expect((await db.getItem(1))!['wearCount'], 0);
    expect((await db.getItem(11))!['wearCount'], 1);
  });

  test('not worn in a while ignores pieces added recently', () async {
    final now = DateTime(2026, 10, 9);
    final old = await addItem('Shirts', added: DateTime(2026, 8, 1));
    await addItem('Shirts', added: DateTime(2026, 10, 8)); // new, never worn
    final worn = await addItem('Pants', added: DateTime(2026, 8, 1));
    await db.logOutfit([worn], 'Casual', when: DateTime(2026, 10, 7));

    final forgotten = await db.getNotWornInAWhile(now: now);
    expect(forgotten.map((i) => i['id']), [old]);
  });

  test('same outfit logged twice today is detected', () async {
    final a = await addItem('Tshirts');
    final b = await addItem('Pants');
    expect(await db.isLoggedToday([a, b]), isFalse);
    await db.logOutfit([b, a], 'Casual');
    expect(await db.isLoggedToday([a, b]), isTrue);
  });

  test('deleting an item removes its photo file', () async {
    final photo = File('${tmp.path}/item_1.jpg')..writeAsStringSync('img');
    final id = await db.insertItem({'type': 'Shirts', 'color': 'white', 'imagePath': 'item_1.jpg', 'dateAdded': DateTime.now().toIso8601String()});
    await db.deleteItem(id);
    expect(photo.existsSync(), isFalse);
    expect(await db.getItem(id), isNull);
  });
}
