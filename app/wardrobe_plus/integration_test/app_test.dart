// End-to-end test on a simulator/phone against the real backend.
//
// WARNING: `flutter test integration_test` UNINSTALLS the app when it finishes,
// which deletes every closet on that device. Run it on a spare simulator, never
// on a phone or simulator with real data.
//
//   cd backend && ./start.sh                      (in one terminal)
//   cd app/wardrobe_plus && flutter test integration_test \
//       --dart-define=SERVER_URL=http://localhost:5000 \
//       --dart-define=PHOTOS_DIR=$PWD/../../ml-model/holdout/images
//
// The photos are classified by the real server (same as the Add screen) and the
// rest of the app is driven through the UI. Uses its own database file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wardrobe_plus/main.dart';
import 'package:wardrobe_plus/services/api_client.dart';
import 'package:wardrobe_plus/services/config.dart';
import 'package:wardrobe_plus/services/database_helper.dart';
import 'package:wardrobe_plus/services/image_store.dart';

const photosDir = String.fromEnvironment('PHOTOS_DIR');
const pauseMs = int.fromEnvironment('PAUSE_MS', defaultValue: 0); // >0 to watch/screenshot

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> pause(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (pauseMs > 0) {
    await Future<void>.delayed(const Duration(milliseconds: pauseMs));
    await tester.pump();
  }
}

Future<void> tapTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).last);
  await tester.pumpAndSettle();
}

/// Stands in for the camera/photo library: "picks" a fixed photo from disk.
class FakePicker extends ImagePickerPlatform {
  String path = '';
  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile(path);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full app flow', (tester) async {
    expect(photosDir, isNotEmpty, reason: 'pass --dart-define=PHOTOS_DIR=...');

    // Fresh state, but put the user's real settings back afterwards
    final prefs = await SharedPreferences.getInstance();
    final saved = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    addTearDown(() async {
      await prefs.clear();
      for (final e in saved.entries) {
        final v = e.value;
        if (v is bool) await prefs.setBool(e.key, v);
        if (v is int) await prefs.setInt(e.key, v);
        if (v is double) await prefs.setDouble(e.key, v);
        if (v is String) await prefs.setString(e.key, v);
        if (v is List) await prefs.setStringList(e.key, v.cast<String>());
      }
    });
    await prefs.clear();
    await AppConfig.load();
    await ImageStore.init();
    final dbPath = p.join(await getDatabasesPath(), 'wardrobe_integration_test.db');
    if (File(dbPath).existsSync()) File(dbPath).deleteSync();
    await DatabaseHelper.useDatabaseAt(dbPath);

    // A fresh account for this run (the photo endpoints need a sign-in token)
    final email = 'it${DateTime.now().millisecondsSinceEpoch}@test.local';
    const password = 'test-pass-123';
    ApiClient.token = (await ApiClient.register('Atharva', email, password))['token'] as String;

    // Classify real photos through the server and save them like the Add screen does
    final db = DatabaseHelper.instance;
    final added = <String, Map<String, dynamic>>{};
    for (final name in ['khushshirt1', 'harshjeans1', 'khushtshirt1', 'khushpant1', 'manaswidress4']) {
      final file = File('$photosDir/$name.jpeg');
      final result = await ApiClient.classify(file);
      added[name] = result;
      await db.insertItem({
        'type': result['type'],
        'color': result['color'],
        'confidence': result['confidence'],
        'imagePath': await ImageStore.save(file),
        'dateAdded': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      });
    }
    expect(added['khushshirt1']!['type'], 'Shirts');
    expect(added['harshjeans1']!['type'], 'Pants');
    expect(added['manaswidress4']!['color'], 'red');

    // Onboarding -> sign in (wrong password first) -> home
    ApiClient.token = null;
    await tester.pumpWidget(const WardrobePlusApp());
    await waitFor(tester, find.text('Skip'));
    await pause(tester);
    await tester.tap(find.text('Skip'));
    await waitFor(tester, find.byKey(const Key('email-field')));
    await tester.enterText(find.byKey(const Key('email-field')), email);
    await tester.enterText(find.byKey(const Key('password-field')), 'wrong-password');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-auth')));
    await waitFor(tester, find.text('Wrong email or password.'));
    await pause(tester);
    final passwordField = find.byKey(const Key('password-field'));
    await tester.tap(passwordField);
    await tester.pumpAndSettle();
    await tester.enterText(passwordField, password);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordField).controller!.text, password);
    await tester.tap(find.byKey(const Key('submit-auth')));
    await waitFor(tester, find.textContaining('Atharva'));
    expect(find.text('Haven\'t Worn in a While'), findsOneWidget);
    await pause(tester);

    // Add screen: upload a photo with a busy striped background (slow cut-out path)
    final picker = FakePicker()..path = '$photosDir/harshtrousers1.jpeg';
    ImagePickerPlatform.instance = picker;
    await tapTab(tester, Icons.add_circle_outline);
    await tester.tap(find.text('Upload'));
    await waitFor(tester, find.text('AI TAGS — TAP TO CORRECT'), seconds: 90);
    expect(find.textContaining('confident this is a pants'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('add-to-closet')), 300, scrollable: find.byType(Scrollable).first);
    await pause(tester);
    await tester.tap(find.byKey(const Key('add-to-closet')));

    // Saving jumps to the closet: now 6 items, filter to pants
    await waitFor(tester, find.text('6 items'));
    await pause(tester);
    await tester.tap(find.text('Pants · 3'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 6 items'), findsOneWidget);
    await pause(tester);

    // Detail + edit colour
    await tester.tap(find.text('Pants').first);
    await waitFor(tester, find.text('TIMES WORN'));
    await pause(tester);
    await tester.tap(find.byKey(const Key('edit-item')));
    await waitFor(tester, find.text('COLOUR'));
    await tester.tap(find.text('Olive'));
    await tester.pump();
    await pause(tester);
    await tester.tap(find.byKey(const Key('save-edit')));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Olive'));
    expect(find.text('TYPE'), findsNothing, reason: 'edit sheet closed');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Outfit generator (real /suggest)
    await tapTab(tester, Icons.auto_awesome_outlined);
    await waitFor(tester, find.textContaining('% match'));
    await pause(tester);
    await tester.tap(find.text('Office'));
    await waitFor(tester, find.textContaining('% match'));
    expect(find.text('T-shirt'), findsNothing, reason: 'T-shirts are not office wear');
    await tester.tap(find.text('Casual'));
    await waitFor(tester, find.textContaining('% match'));
    await tester.scrollUntilVisible(find.byKey(const Key('wear-today')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('wear-today')));
    await waitFor(tester, find.text('Logged for today ✓'));
    await pause(tester);
    // Wait for the snackbar to clear, then ask for a different outfit
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (find.byType(SnackBar).evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('show-another')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('show-another')));
    await tester.pump(const Duration(milliseconds: 300));
    await waitFor(tester, find.textContaining('% match'));
    await tester.scrollUntilVisible(find.byKey(const Key('wear-today')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Wear This Today'), findsOneWidget);
    expect(find.text('Logged for today ✓'), findsNothing, reason: 'a different outfit should be shown');
    await pause(tester);

    // Find a match: start from the white shirt, get pants ranked
    await tester.scrollUntilVisible(find.byKey(const Key('start-from-piece')), -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('start-from-piece')));
    await waitFor(tester, find.text('Pick a top or pants'));
    await pause(tester);
    await tester.tap(find.text('Shirt').last);
    await waitFor(tester, find.text('Best match'));
    await tester.scrollUntilVisible(find.text('ALL PANTS RANKED'), 300, scrollable: find.byType(Scrollable).first);
    await pause(tester);
    await tester.scrollUntilVisible(find.text('Office'), -300, scrollable: find.byType(Scrollable).first);
    await pause(tester);
    await tester.tap(find.text('Office'));
    await waitFor(tester, find.textContaining('Fits office'));
    await tester.ensureVisible(find.byKey(const Key('match-wear-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-wear-today')));
    await waitFor(tester, find.text('Logged for today ✓'));
    await pause(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Home shows today's outfit
    await tapTab(tester, Icons.home_outlined);
    await waitFor(tester, find.text('Today\'s outfit'));
    await pause(tester);

    // History via insights
    await tester.scrollUntilVisible(find.text('OUTFITS WORN'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('OUTFITS WORN'));
    await waitFor(tester, find.text('2 outfits worn'));
    await pause(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Profile
    await tapTab(tester, Icons.person_outline);
    await waitFor(tester, find.text('Atharva'));
    await tester.tap(find.text('How suggestions work'));
    await waitFor(tester, find.text('How Wardrobe+ works'));
    await pause(tester);
  });
}
