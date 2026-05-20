import '../../../core/crypto/kdf.dart';
import '../../../core/storage/paths.dart';
import '../vault_descriptor.dart';

class GetVaultKdfProfileUseCase {
  GetVaultKdfProfileUseCase(this._paths);

  final VaultPaths _paths;

  Future<KdfProfile> call() async {
    if (!VaultDescriptor.exists(_paths)) return KdfProfile.standard;
    final descriptor = await VaultDescriptor.load(_paths);
    return KdfProfile.fromParams(descriptor.kdf);
  }
}
