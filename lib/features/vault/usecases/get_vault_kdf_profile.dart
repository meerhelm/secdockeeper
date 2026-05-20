import '../../../core/crypto/kdf.dart';
import '../../../core/storage/paths.dart';
import '../vault_descriptor.dart';

class VaultKdfStatus {
  const VaultKdfStatus({
    required this.profile,
    required this.params,
    required this.belowDefault,
  });

  final KdfProfile profile;
  final KdfParams params;

  /// True when the persisted KDF params are weaker than [KdfParams.defaultParams]
  /// along any dimension (memory, iterations, parallelism). Surfaces the
  /// "harden vault" banner in Settings.
  final bool belowDefault;
}

class GetVaultKdfProfileUseCase {
  GetVaultKdfProfileUseCase(this._paths);

  final VaultPaths _paths;

  Future<VaultKdfStatus> call() async {
    if (!VaultDescriptor.exists(_paths)) {
      return const VaultKdfStatus(
        profile: KdfProfile.standard,
        params: KdfParams.defaultParams,
        belowDefault: false,
      );
    }
    final descriptor = await VaultDescriptor.load(_paths);
    final params = descriptor.kdf;
    final defaults = KdfParams.defaultParams;
    final below = params.memory < defaults.memory ||
        params.iterations < defaults.iterations ||
        params.parallelism < defaults.parallelism;
    return VaultKdfStatus(
      profile: KdfProfile.fromParams(params),
      params: params,
      belowDefault: below,
    );
  }
}
