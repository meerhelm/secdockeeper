import '../vault_service.dart';

class InitializeVaultUseCase {
  InitializeVaultUseCase(this._vault);

  final VaultService _vault;

  Future<void> call(String masterPassword) =>
      _vault.initialize(masterPassword);
}
