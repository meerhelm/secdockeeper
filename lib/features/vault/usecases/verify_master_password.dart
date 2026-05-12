import '../vault_service.dart';

class VerifyMasterPasswordUseCase {
  VerifyMasterPasswordUseCase(this._vault);

  final VaultService _vault;

  Future<bool> call(String password) => _vault.verifyPassword(password);
}
