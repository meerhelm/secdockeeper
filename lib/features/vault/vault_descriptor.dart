import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/crypto/kdf.dart';
import '../../core/storage/paths.dart';

class VaultDescriptor {
  const VaultDescriptor({
    required this.version,
    required this.salt,
    required this.kdf,
  });

  final int version;
  final Uint8List salt;
  final KdfParams kdf;

  static const _fileName = 'vault.json';
  static const _backupFileName = 'vault.json.bak';
  static const _currentVersion = 1;
  static const _saltLength = 16;

  static File _file(VaultPaths paths) => File(p.join(paths.root.path, _fileName));
  static File _backupFile(VaultPaths paths) => File(p.join(paths.root.path, _backupFileName));

  static bool exists(VaultPaths paths) => _file(paths).existsSync();

  static Future<void> backup(VaultPaths paths) async {
    final original = _file(paths);
    if (original.existsSync()) {
      await original.copy(_backupFile(paths).path);
    }
  }

  static Future<void> deleteBackup(VaultPaths paths) async {
    final b = _backupFile(paths);
    if (b.existsSync()) await b.delete();
  }

  static Future<VaultDescriptor?> loadBackup(VaultPaths paths) async {
    final b = _backupFile(paths);
    if (!b.existsSync()) return null;
    return _loadFromFile(b);
  }

  static VaultDescriptor createFresh() => VaultDescriptor(
        version: _currentVersion,
        salt: randomBytes(_saltLength),
        kdf: KdfParams.defaultParams,
      );

  Map<String, Object?> toJson() => {
        'version': version,
        'salt': base64Encode(salt),
        'kdf': kdf.toJson(),
      };

  factory VaultDescriptor.fromJson(Map<String, Object?> json) => VaultDescriptor(
        version: json['version']! as int,
        salt: Uint8List.fromList(base64Decode(json['salt']! as String)),
        kdf: KdfParams.fromJson((json['kdf']! as Map).cast<String, Object?>()),
      );

  /// The salt in vault.json is the only copy, so the file is replaced via
  /// write-to-temp + rename: a crash leaves either the old or the new file.
  Future<void> save(VaultPaths paths) =>
      writeFileAtomically(_file(paths), jsonEncode(toJson()));

  static Future<VaultDescriptor> load(VaultPaths paths) async {
    return _loadFromFile(_file(paths));
  }

  static Future<VaultDescriptor> _loadFromFile(File file) async {
    final raw = await file.readAsString();
    return VaultDescriptor.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }
}

Future<void> writeFileAtomically(File file, String contents) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(contents, flush: true);
  await tmp.rename(file.path);
}
