import '../biometric_service.dart';
import '../lock_settings.dart';

/// Returns true only if the user has enabled biometric unlock AND the device
/// currently supports it. Either condition can flip independently — biometric
/// can be enabled in settings but become unavailable if the user disabled the
/// device-level lock.
class IsBiometricUnlockReadyUseCase {
  IsBiometricUnlockReadyUseCase({
    required BiometricService biometrics,
    required LockSettings lockSettings,
  })  : _biometrics = biometrics,
        _lockSettings = lockSettings;

  final BiometricService _biometrics;
  final LockSettings _lockSettings;

  Future<bool> call() async {
    if (!_lockSettings.biometricEnabled) return false;
    return _biometrics.isAvailable;
  }
}
