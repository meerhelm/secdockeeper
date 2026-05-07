import '../../documents/document_open_service.dart';
import '../../security/lock_settings.dart';
import '../vault_service.dart';

class DestroyVaultUseCase {
  DestroyVaultUseCase({
    required VaultService vault,
    required DocumentOpenService opener,
    required LockSettings lockSettings,
  })  : _vault = vault,
        _opener = opener,
        _lockSettings = lockSettings;

  final VaultService _vault;
  final DocumentOpenService _opener;
  final LockSettings _lockSettings;

  Future<void> call() async {
    await _opener.deleteAllTemp();
    await _lockSettings.clearAll();
    await _vault.destroy();
  }
}
