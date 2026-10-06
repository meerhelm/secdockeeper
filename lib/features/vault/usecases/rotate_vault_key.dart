import '../../../core/crypto/kdf.dart';
import '../../../core/crypto/tag_hmac.dart';
import '../../../core/crypto/vault_crypto.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/paths.dart';
import '../../../core/storage/vault_database.dart';
import '../key_rotation_journal.dart';
import '../vault_descriptor.dart';
import '../vault_key_migrator.dart';
import '../vault_service.dart';

class RotateVaultKeyUseCase {
  RotateVaultKeyUseCase({
    required VaultService vault,
    required VaultPaths paths,
  })  : _vault = vault,
        _paths = paths;

  final VaultService _vault;
  final VaultPaths _paths;

  Future<void> call(String newMasterPassword) async {
    if (_vault.state != VaultState.unlocked) {
      throw StateError('Vault must be unlocked to rotate keys');
    }

    final oldKek = _vault.kek;
    final oldDescriptor = await VaultDescriptor.load(_paths);
    final newDescriptor = VaultDescriptor(
      version: oldDescriptor.version,
      salt: randomBytes(16),
      kdf: oldDescriptor.kdf,
    );
    final newKek = await Kdf(params: newDescriptor.kdf).deriveKek(
      password: newMasterPassword,
      salt: newDescriptor.salt,
    );

    // 1. Journal first. From here on, either password can recover the vault
    //    no matter where the steps below stop (see VaultService.unlock).
    final journal = await KeyRotationJournal.create(
      oldDescriptor: oldDescriptor,
      newDescriptor: newDescriptor,
      oldKek: oldKek,
      newKek: newKek,
    );
    await journal.save(_paths);

    try {
      // 2. Re-wrap DEKs and hidden tags, 3. rekey SQLCipher,
      // 4. switch vault.json to the new salt, 5. drop the journal.
      final db = _vault.db;
      await VaultKeyMigrator(target: newKek, other: oldKek).rewrapAll(db);
      await VaultDatabase.fromRaw(db).rekey(await kekToDbPassword(newKek));
      await newDescriptor.save(_paths);
      await KeyRotationJournal.delete(_paths);
      await VaultDescriptor.deleteBackup(_paths);
    } catch (e, st) {
      log.e('[rotate_vault_key] rotation failed; rolling back',
          error: e, stackTrace: st);
      await _vault.abortRotation(oldKek);
      rethrow;
    }

    _vault.updateKeysAfterRotation(newKek, await deriveTagHmacKey(newKek));
  }
}
