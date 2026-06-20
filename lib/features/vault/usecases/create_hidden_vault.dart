import '../vault_service.dart';

/// Creates (or silently replaces) the single hidden vault. A hidden vault is a
/// plausible-deniability vault: it is opened by typing its own password into
/// the normal lock screen, and is wiped on repeated wrong-password attempts.
class CreateHiddenVaultUseCase {
  CreateHiddenVaultUseCase(this._vault);

  final VaultService _vault;

  Future<void> call(String password) => _vault.createHiddenVault(password);
}
