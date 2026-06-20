import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';

/// Central registry of the short-lived plaintext temp directories the app uses.
///
/// Every code path that writes decrypted material to disk (the system-viewer
/// hand-off, share export, OCR scratch, backup staging) must do so under one of
/// these named subdirectories of the OS temp dir. [wipeAll] is wired into vault
/// lock and destroy so none of it outlives an unlocked session.
class SecureTemp {
  SecureTemp._();

  /// The system viewer hand-off — full decrypted document plaintext.
  static const view = 'sdk_view';

  /// Share export staging — decrypted plaintext + the raw export DEK file.
  static const share = 'sdk_share';

  /// OCR source scratch — decrypted image bytes handed to ML Kit.
  static const ocr = 'ocr_scratch';

  /// Backup staging — the (already-encrypted) archive before it is shared.
  static const backup = 'sdk_backup';

  static const _all = [view, share, ocr, backup];

  /// Resolves (and creates) one of the known temp subdirectories.
  static Future<Directory> dir(String name) async {
    assert(_all.contains(name), 'unknown secure temp subdir: $name');
    final tmp = await getTemporaryDirectory();
    final d = Directory(p.join(tmp.path, name));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Collapses an (often attacker-controlled) document name to a safe basename
  /// before it is used to build a temp file path. Strips directory components
  /// and separators so a name like `../../vault.db` cannot escape the temp dir.
  static String safeName(String name) {
    var base = p.basename(name.replaceAll(r'\', '/'));
    base = base.replaceAll(RegExp(r'[\\/]'), '_');
    if (base.isEmpty || base == '.' || base == '..') return 'document';
    return base;
  }

  /// Deletes every known temp subdirectory. Best-effort: a file still held open
  /// by a system viewer may resist deletion, which is logged but not fatal.
  static Future<void> wipeAll() async {
    final tmp = await getTemporaryDirectory();
    for (final name in _all) {
      final d = Directory(p.join(tmp.path, name));
      if (!d.existsSync()) continue;
      try {
        await d.delete(recursive: true);
      } catch (e, st) {
        log.w('[secure_temp] failed to wipe $name', error: e, stackTrace: st);
      }
    }
  }
}
