import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores clothing photos in the app's Documents folder.
///
/// Only the file NAME is saved in the database. On iOS the full path to the
/// app's folder changes whenever the app is reinstalled or rebuilt from Xcode,
/// so a saved full path stops working and the closet shows placeholders.
/// Storing the name and rebuilding the path at runtime fixes that.
class ImageStore {
  static Directory? _dir;

  static Future<void> init() async {
    _dir ??= await getApplicationDocumentsDirectory();
  }

  /// For tests.
  static void useDirectory(Directory dir) => _dir = dir;

  /// Copies a picked photo into permanent storage and returns the name to save.
  static Future<String> save(File picked) async {
    await init();
    final name = 'item_${DateTime.now().millisecondsSinceEpoch}${_extension(picked.path)}';
    await picked.copy(p.join(_dir!.path, name));
    return name;
  }

  /// Turns whatever is stored in the database (a name, or an old full path)
  /// into a file in the current Documents folder, or null if it's gone.
  static File? resolve(String? stored) {
    final path = resolvePath(stored, _dir?.path);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  static String? resolvePath(String? stored, String? documentsDir) {
    if (stored == null || stored.isEmpty || documentsDir == null) return null;
    // Old rows stored full paths. Photos saved into Documents keep their file
    // name when the app folder moves, so the name is enough to find them.
    return p.join(documentsDir, p.basename(stored));
  }

  static Future<void> delete(String? stored) async {
    final file = resolve(stored);
    if (file != null) await file.delete();
  }

  static String _extension(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext.isEmpty ? '.jpg' : ext;
  }
}
