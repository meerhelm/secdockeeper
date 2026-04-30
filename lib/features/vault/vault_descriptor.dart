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
  static const _currentVersion = 1;
  static const _saltLength = 16;

  static File _file(VaultPaths paths) => File(p.join(paths.root.path, _fileName));

  static bool exists(VaultPaths paths) => _file(paths).existsSync();

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
    final raw = await _file(paths).readAsString();
    final json = jsonDecode(raw) as Map<String, Object?>;
    return VaultDescriptor(
      version: json['version']! as int,
      salt: Uint8List.fromList(base64Decode(json['salt']! as String)),
      kdf: KdfParams.fromJson((json['kdf']! as Map).cast<String, Object?>()),
    );
  }
}
