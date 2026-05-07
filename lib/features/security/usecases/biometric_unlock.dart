import '../../vault/vault_service.dart';
import '../biometric_service.dart';
import '../lock_settings.dart';

sealed class BiometricUnlockResult {
  const BiometricUnlockResult();
}

class BiometricUnlockSuccess extends BiometricUnlockResult {
  const BiometricUnlockSuccess();
}

/// User dismissed the platform prompt or it failed silently.
class BiometricUnlockCancelled extends BiometricUnlockResult {
  const BiometricUnlockCancelled();
}

/// Biometric was enabled but the stored credential is gone.
class BiometricUnlockNoStoredPassword extends BiometricUnlockResult {
  const BiometricUnlockNoStoredPassword();
}

/// Stored credential no longer unlocks the vault — biometric was disabled
/// as a side effect.
class BiometricUnlockInvalidStoredPassword extends BiometricUnlockResult {
  const BiometricUnlockInvalidStoredPassword();
}

class BiometricUnlockFailed extends BiometricUnlockResult {
  const BiometricUnlockFailed(this.error);
  final Object error;
}

class BiometricUnlockUseCase {
  BiometricUnlockUseCase({
    required BiometricService biometrics,
    required LockSettings lockSettings,
    required VaultService vault,
  })  : _biometrics = biometrics,
        _lockSettings = lockSettings,
        _vault = vault;

  final BiometricService _biometrics;
  final LockSettings _lockSettings;
  final VaultService _vault;

  Future<BiometricUnlockResult> call({
    String reason = 'Unlock SecDockKeeper',
  }) async {
    try {
      final ok = await _biometrics.authenticate(reason: reason);
      if (!ok) return const BiometricUnlockCancelled();

      final pwd = await _lockSettings.readStoredPassword();
      if (pwd == null) return const BiometricUnlockNoStoredPassword();

      final unlocked = await _vault.unlock(pwd);
      if (!unlocked) {
        await _lockSettings.disableBiometric();
        return const BiometricUnlockInvalidStoredPassword();
      }
      return const BiometricUnlockSuccess();
    } catch (e) {
      return BiometricUnlockFailed(e);
    }
  }
}
