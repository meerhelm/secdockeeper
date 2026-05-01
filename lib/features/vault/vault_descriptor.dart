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

  Future<void> save(VaultPaths paths) async {
    final file = _file(paths);
    final json = {
      'version': version,
      'salt': base64Encode(salt),
      'kdf': kdf.toJson(),
    };
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  static Future<VaultDescriptor> load(VaultPaths paths) async {
    return _loadFromFile(_file(paths));
  }

  static Future<VaultDescriptor> _loadFromFile(File file) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, Object?>;
    return VaultDescriptor(
      version: json['version']! as int,
      salt: Uint8List.fromList(base64Decode(json['salt']! as String)),
      kdf: KdfParams.fromJson((json['kdf']! as Map).cast<String, Object?>()),
    );
  }
}
