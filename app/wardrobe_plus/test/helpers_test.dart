import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobe_plus/services/catalog.dart';
import 'package:wardrobe_plus/services/config.dart';
import 'package:wardrobe_plus/services/formatters.dart';
import 'package:wardrobe_plus/services/image_store.dart';

void main() {
  group('server address', () {
    test('adds scheme and default port', () {
      expect(AppConfig.normalize('my-mac.local'), 'http://my-mac.local:5000');
      expect(AppConfig.normalize('192.168.1.48'), 'http://192.168.1.48:5000');
    });
    test('keeps an explicit port and strips trailing slash', () {
      expect(AppConfig.normalize(' http://192.168.1.48:8080/ '), 'http://192.168.1.48:8080');
    });
    test('empty input falls back to the default', () {
      expect(AppConfig.normalize('  '), AppConfig.defaultBaseUrl);
    });
  });

  group('image paths', () {
    test('old full paths are rebuilt inside the current Documents folder', () {
      const old = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/1712345.jpg';
      expect(ImageStore.resolvePath(old, '/new/Documents'), '/new/Documents/1712345.jpg');
    });
    test('file names are joined to the Documents folder', () {
      expect(ImageStore.resolvePath('item_1.jpg', '/docs'), '/docs/item_1.jpg');
    });
    test('missing values resolve to nothing', () {
      expect(ImageStore.resolvePath(null, '/docs'), isNull);
      expect(ImageStore.resolvePath('', '/docs'), isNull);
    });
  });

  group('dates', () {
    final now = DateTime(2026, 10, 9, 10);
    test('worn ago', () {
      expect(wornAgo(null, now: now), 'Never');
      expect(wornAgo(DateTime(2026, 10, 9, 8).toIso8601String(), now: now), 'Today');
      expect(wornAgo(DateTime(2026, 10, 8, 23).toIso8601String(), now: now), 'Yesterday');
      expect(wornAgo(DateTime(2026, 10, 2).toIso8601String(), now: now), '7 days ago');
      expect(wornAgo(DateTime(2026, 9, 11).toIso8601String(), now: now), '4 weeks ago');
    });
    test('short date drops the year when it is this year', () {
      expect(shortDate(DateTime(2026, 9, 9).toIso8601String(), now: now), '9 Sep');
      expect(shortDate(DateTime(2025, 9, 9).toIso8601String(), now: now), '9 Sep 2025');
    });
    test('day heading', () {
      expect(dayHeading(DateTime(2026, 10, 9, 7), now: now), 'Today');
      expect(dayHeading(DateTime(2026, 10, 7), now: now), 'Wed, 7 Oct');
    });
    test('converts local timestamps to UTC for the server', () {
      final local = DateTime(2026, 10, 9, 10);
      expect(toUtcIso(local.toIso8601String()), local.toUtc().toIso8601String());
      expect(toUtcIso(null), isNull);
    });
  });

  test('plural', () {
    expect(plural(1, 'item'), '1 item');
    expect(plural(5, 'item'), '5 items');
  });

  group('catalog', () {
    test('labels', () {
      expect(Catalog.typeLabel('Tshirts'), 'T-shirt');
      expect(Catalog.colorLabel('light blue'), 'Light blue');
      expect(Catalog.colorLabel('unknown'), 'Unknown colour');
      expect(Catalog.colorNames.last, 'multicolor');
    });
  });
}
