import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';

/// Every place outside the vault where the app leaves plaintext (or a raw
/// share key) on disk. All of it lives under the platform temp directory.
class TempFiles {
  TempFiles._();

  /// Decrypted documents handed to the system viewer.
  static const viewDir = 'sdk_view';

  /// Share exports: the ciphertext sits next to its raw DEK.
  static const shareDir = 'sdk_share';

  /// Images handed to ML Kit during import.
  static const ocrDir = 'ocr_scratch';

  /// Encrypted backup ZIPs waiting for the share sheet.
  static const backupDir = 'sdk_backup';

  static Future<Directory> dir(String name) async {
    final tmp = await getTemporaryDirectory();
    return Directory(p.join(tmp.path, name));
  }

  /// Deletes every plaintext temp location. Backups are encrypted and may
  /// still be read by a share target, so they are only removed when
  /// [includeBackups] is set (on app start).
  static Future<void> wipe({bool includeBackups = false}) async {
    final names = [viewDir, shareDir, ocrDir, if (includeBackups) backupDir];
    for (final name in names) {
      final d = await dir(name);
      if (!d.existsSync()) continue;
      try {
        await d.delete(recursive: true);
      } catch (e, st) {
        log.w('[temp_files] cleanup of $name failed', error: e, stackTrace: st);
      }
    }
    await clearPickerCache();
  }

  /// file_picker copies picked files into its own cache on Android; those
  /// are plaintext copies of whatever was just imported.
  static Future<void> clearPickerCache() async {
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (e, st) {
      log.w('[temp_files] file_picker cache cleanup failed',
          error: e, stackTrace: st);
    }
  }
}

/// Reduces an untrusted document name (e.g. `original_name` from a shared
/// package) to a single path segment that can't escape its directory.
String sanitizeFileName(String name) {
  final base = p.posix.basename(name.replaceAll('\\', '/'));
  final cleaned = base.replaceAll(RegExp(r'[\x00-\x1f]'), '').trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'document';
  return cleaned;
}
