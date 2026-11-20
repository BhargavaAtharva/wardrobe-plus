import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wardrobe_plus/services/api_client.dart';
import 'package:wardrobe_plus/services/database_helper.dart';
import 'package:wardrobe_plus/services/user_profile.dart';

/// What the server returns from /auth/login or /auth/register.
Map<String, dynamic> serverReply(int id, String email, {String token = 'tok'}) => {
      'token': '$token-$id',
      'user': {'id': id, 'email': email, 'name': email.split('@').first, 'created_at': '2026-10-01T10:00:00+00:00'},
    };

void main() {
  late Directory tmp;
  final db = DatabaseHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wardrobe_accounts');
    await databaseFactory.setDatabasesPath(tmp.path);
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.useDatabaseAt(null);
    await DatabaseHelper.close();
  });

  tearDown(() async {
    await DatabaseHelper.close();
    await tmp.delete(recursive: true);
  });

  Future<void> addShirt() => db.insertItem({
        'type': 'Shirts',
        'color': 'white',
        'imagePath': 'a.jpg',
        'dateAdded': DateTime.now().toIso8601String(),
      });

  test('each account has its own closet', () async {
    await UserProfile.completeSignIn(serverReply(1, 'ath@example.com'));
    await addShirt();
    expect(await db.getTotalItems(), 1);

    await UserProfile.signOut(tellServer: false);
    await UserProfile.completeSignIn(serverReply(2, 'manaswi@example.com'));
    expect(await db.getTotalItems(), 0);

    await UserProfile.signOut(tellServer: false);
    await UserProfile.completeSignIn(serverReply(1, 'ath@example.com'));
    expect(await db.getTotalItems(), 1);
  });

  test('sign in stores the token and the account details', () async {
    await UserProfile.completeSignIn(serverReply(7, 'demo@wardrobeplus.app'));
    expect(ApiClient.token, 'tok-7');
    expect(await UserProfile.email(), 'demo@wardrobeplus.app');
    expect(await UserProfile.name(), 'demo');
    expect(await UserProfile.memberSince(), DateTime.parse('2026-10-01T10:00:00+00:00'));
  });

  test('restoring on app start reopens the signed-in closet and token', () async {
    await UserProfile.completeSignIn(serverReply(1, 'ath@example.com'));
    await addShirt();
    ApiClient.token = null;
    await DatabaseHelper.close(); // app killed
    expect(await UserProfile.restore(), isTrue);
    expect(ApiClient.token, 'tok-1');
    expect(await db.getTotalItems(), 1);
  });

  test('signing out clears the token but keeps the closet and last email', () async {
    await UserProfile.completeSignIn(serverReply(1, 'ath@example.com'));
    await addShirt();
    await UserProfile.signOut(tellServer: false);
    expect(ApiClient.token, isNull);
    expect(await UserProfile.restore(), isFalse);
    expect(await UserProfile.lastEmail(), 'ath@example.com');
    expect(File(p.join(tmp.path, DatabaseHelper.fileNameFor('ath_example_com'))).existsSync(), isTrue);
  });

  test('the old shared closet goes to the first account only', () async {
    final legacy = await openDatabase(p.join(tmp.path, DatabaseHelper.legacyFileName), version: 4,
        onCreate: (d, v) => d.execute('CREATE TABLE clothing (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, '
            'color TEXT, confidence REAL, imagePath TEXT, dateAdded TEXT NOT NULL, lastWorn TEXT, wearCount INTEGER DEFAULT 0)'));
    await legacy.insert('clothing', {'type': 'Pants', 'dateAdded': '2026-10-01T10:00:00'});
    await legacy.close();

    await UserProfile.completeSignIn(serverReply(1, 'ath@example.com'));
    expect(await db.getTotalItems(), 1);
    await UserProfile.signOut(tellServer: false);
    await UserProfile.completeSignIn(serverReply(2, 'manaswi@example.com'));
    expect(await db.getTotalItems(), 0);
  });

  test('closet ids come from the email', () {
    expect(UserProfile.idFor(' Demo@WardrobePlus.app '), 'demo_wardrobeplus_app');
  });
}
