import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/crypto/kdf.dart';
import '../../core/storage/paths.dart';

/// A VMK (vault master key) wrapped under the KEK with AES-GCM. Present only on
/// version-2 descriptors. See [VaultDescriptor] for why the indirection exists.
class WrappedVmk {
  const WrappedVmk({required this.nonce, required this.ciphertext, required this.mac});

  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  Map<String, Object?> toJson() => {
        'nonce': base64Encode(nonce),
        'ct': base64Encode(ciphertext),
        'mac': base64Encode(mac),
      };

  factory WrappedVmk.fromJson(Map<String, Object?> json) => WrappedVmk(
        nonce: Uint8List.fromList(base64Decode(json['nonce']! as String)),
        ciphertext: Uint8List.fromList(base64Decode(json['ct']! as String)),
        mac: Uint8List.fromList(base64Decode(json['mac']! as String)),
      );
}

/// Plaintext descriptor stored next to the encrypted DB. It is useless without
/// the password.
///
/// **Version 1 (legacy):** stores only the Argon2 salt + KDF params. The KEK
/// derived from the password is used directly both to wrap per-document DEKs and
/// (base64-encoded) as the SQLCipher passphrase.
///
/// **Version 2:** additionally stores a [WrappedVmk] — a random vault master key
/// sealed under the KEK. On unlock the VMK is unwrapped and all working keys
/// (DB passphrase, DEK-wrap key, hidden-tag HMAC key) are HKDF-derived from the
/// *VMK*, not the KEK. This buys two things:
///   * key separation — the SQLCipher passphrase is no longer the same secret
///     that wraps DEKs (finding M-1);
///   * O(1), crash-safe password rotation — changing the password only re-wraps
///     the VMK and rewrites this one file; DEKs, the DB passphrase and tag
///     hashes are all unchanged (finding M-3).
class VaultDescriptor {
  const VaultDescriptor({
    required this.version,
    required this.salt,
    required this.kdf,
    this.wrappedVmk,
  });

  final int version;
  final Uint8List salt;
  final KdfParams kdf;
  final WrappedVmk? wrappedVmk;

  bool get usesVmk => version >= 2 && wrappedVmk != null;

  static const _fileName = 'vault.json';
  static const _backupFileName = 'vault.json.bak';
  static const currentVersion = 2;
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

  /// Fresh salt + default KDF params for a brand-new vault. The caller derives
  /// the KEK, generates and wraps the VMK, then calls [withWrappedVmk] before
  /// saving so the persisted descriptor is a complete version-2 record.
  static VaultDescriptor createFresh() => VaultDescriptor(
        version: currentVersion,
        salt: randomBytes(_saltLength),
        kdf: KdfParams.defaultParams,
      );

  VaultDescriptor withWrappedVmk(WrappedVmk wrapped) => VaultDescriptor(
        version: version,
        salt: salt,
        kdf: kdf,
        wrappedVmk: wrapped,
      );

  /// Re-issues the descriptor with a new salt and freshly-wrapped VMK, keeping
  /// the version and KDF params. Used by password rotation on v2 vaults.
  VaultDescriptor rotated({
    required Uint8List newSalt,
    required WrappedVmk newWrappedVmk,
  }) =>
      VaultDescriptor(
        version: version,
        salt: newSalt,
        kdf: kdf,
        wrappedVmk: newWrappedVmk,
      );

  Future<void> save(VaultPaths paths) async {
    final file = _file(paths);
    final json = <String, Object?>{
      'version': version,
      'salt': base64Encode(salt),
      'kdf': kdf.toJson(),
      if (wrappedVmk != null) 'vmk': wrappedVmk!.toJson(),
    };
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  static Future<VaultDescriptor> load(VaultPaths paths) async {
    return _loadFromFile(_file(paths));
  }

  static Future<VaultDescriptor> _loadFromFile(File file) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, Object?>;
    final vmkJson = json['vmk'];
    return VaultDescriptor(
      version: json['version']! as int,
      salt: Uint8List.fromList(base64Decode(json['salt']! as String)),
      kdf: KdfParams.fromJson((json['kdf']! as Map).cast<String, Object?>()),
      wrappedVmk: vmkJson == null
          ? null
          : WrappedVmk.fromJson((vmkJson as Map).cast<String, Object?>()),
    );
  }
}
