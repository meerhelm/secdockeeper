import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../core/crypto/aead.dart';
import '../../core/storage/paths.dart';
import 'vault_descriptor.dart';

/// Crash-recovery record for a master password change.
///
/// Changing the password re-wraps every DEK, rekeys SQLCipher and rewrites
/// vault.json. Those steps can't share one transaction, so between them the
/// vault is a mix of old-KEK and new-KEK state. The journal is written
/// before any of it and holds both descriptors plus each KEK sealed under
/// the other. Whichever password the user types next recovers both keys,
/// and [VaultService] finishes the vault toward that password.
class KeyRotationJournal {
  const KeyRotationJournal({
    required this.oldDescriptor,
    required this.newDescriptor,
    required this.newKekUnderOld,
    required this.oldKekUnderNew,
  });

  final VaultDescriptor oldDescriptor;
  final VaultDescriptor newDescriptor;
  final SealedBytes newKekUnderOld;
  final SealedBytes oldKekUnderNew;

  static const _fileName = 'vault.json.rotating';
  static const _formatVersion = 1;
  static final _aad = utf8.encode('secdockeeper:key-rotation-journal:v1');

  static File _file(VaultPaths paths) => File(p.join(paths.root.path, _fileName));

  static bool exists(VaultPaths paths) => _file(paths).existsSync();

  static Future<KeyRotationJournal> create({
    required VaultDescriptor oldDescriptor,
    required VaultDescriptor newDescriptor,
    required SecretKey oldKek,
    required SecretKey newKek,
  }) async {
    return KeyRotationJournal(
      oldDescriptor: oldDescriptor,
      newDescriptor: newDescriptor,
      newKekUnderOld: await Aead.seal(
        key: oldKek,
        plaintext: await newKek.extractBytes(),
        aad: _aad,
      ),
      oldKekUnderNew: await Aead.seal(
        key: newKek,
        plaintext: await oldKek.extractBytes(),
        aad: _aad,
      ),
    );
  }

  /// Given a KEK derived from the typed password, returns the other KEK and
  /// the descriptor the vault should end up with. Null when [kek] is neither.
  Future<RotationKeys?> resolve(SecretKey kek) async {
    final asOld = await _tryOpen(kek, newKekUnderOld);
    if (asOld != null) {
      return RotationKeys(target: kek, other: SecretKey(asOld), descriptor: oldDescriptor);
    }
    final asNew = await _tryOpen(kek, oldKekUnderNew);
    if (asNew != null) {
      return RotationKeys(target: kek, other: SecretKey(asNew), descriptor: newDescriptor);
    }
    return null;
  }

  static Future<Uint8List?> _tryOpen(SecretKey key, SealedBytes sealed) async {
    try {
      return await Aead.open(key: key, sealed: sealed, aad: _aad);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  Future<void> save(VaultPaths paths) => writeFileAtomically(
        _file(paths),
        jsonEncode({
          'version': _formatVersion,
          'old': oldDescriptor.toJson(),
          'new': newDescriptor.toJson(),
          'new_kek_under_old': _sealedToJson(newKekUnderOld),
          'old_kek_under_new': _sealedToJson(oldKekUnderNew),
        }),
      );

  static Future<KeyRotationJournal?> load(VaultPaths paths) async {
    final file = _file(paths);
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final version = json['version'] as int?;
    if (version != _formatVersion) {
      throw FormatException('Unsupported key rotation journal version: $version');
    }
    return KeyRotationJournal(
      oldDescriptor: VaultDescriptor.fromJson(_map(json['old'])),
      newDescriptor: VaultDescriptor.fromJson(_map(json['new'])),
      newKekUnderOld: _sealedFromJson(_map(json['new_kek_under_old'])),
      oldKekUnderNew: _sealedFromJson(_map(json['old_kek_under_new'])),
    );
  }

  static Future<void> delete(VaultPaths paths) async {
    final file = _file(paths);
    if (file.existsSync()) await file.delete();
  }

  static Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();

  static Map<String, Object?> _sealedToJson(SealedBytes s) => {
        'n': base64Encode(s.nonce),
        'c': base64Encode(s.ciphertext),
        'm': base64Encode(s.mac),
      };

  static SealedBytes _sealedFromJson(Map<String, Object?> json) => SealedBytes(
        nonce: base64Decode(json['n']! as String),
        ciphertext: base64Decode(json['c']! as String),
        mac: base64Decode(json['m']! as String),
      );
}

class RotationKeys {
  const RotationKeys({
    required this.target,
    required this.other,
    required this.descriptor,
  });

  /// KEK of the password the user just typed — the vault converges on it.
  final SecretKey target;

  /// The KEK some rows (or the SQLCipher key) may still be under.
  final SecretKey other;

  /// Descriptor matching [target]; becomes vault.json once the DB converges.
  final VaultDescriptor descriptor;
}
