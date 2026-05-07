import '../vault_service.dart';

class UnlockVaultUseCase {
  UnlockVaultUseCase(this._vault);

  final VaultService _vault;

  Future<bool> call(String masterPassword) => _vault.unlock(masterPassword);
}
