import '../../documents/document_open_service.dart';
import '../vault_service.dart';

class LockVaultUseCase {
  LockVaultUseCase({
    required VaultService vault,
    required DocumentOpenService opener,
  })  : _vault = vault,
        _opener = opener;

  final VaultService _vault;
  final DocumentOpenService _opener;

  Future<void> call() async {
    await _opener.deleteAllTemp();
    await _vault.lock();
  }
}
