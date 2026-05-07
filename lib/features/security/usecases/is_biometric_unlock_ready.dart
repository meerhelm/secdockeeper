import '../biometric_service.dart';
import '../lock_settings.dart';

class BiometricReadiness {
  const BiometricReadiness({required this.ready, required this.kind});

  final bool ready;
  final BiometricKind kind;

  static const unavailable =
      BiometricReadiness(ready: false, kind: BiometricKind.generic);
}

/// Returns whether biometric unlock is currently usable, plus the kind of
/// biometric (face / fingerprint / generic) so the UI can pick a matching
/// icon and label. Either condition can flip independently — biometric can be
/// enabled in settings but become unavailable if the user disabled the
/// device-level lock.
class IsBiometricUnlockReadyUseCase {
  IsBiometricUnlockReadyUseCase({
    required BiometricService biometrics,
    required LockSettings lockSettings,
  })  : _biometrics = biometrics,
        _lockSettings = lockSettings;

  final BiometricService _biometrics;
  final LockSettings _lockSettings;

  Future<BiometricReadiness> call() async {
    if (!_lockSettings.biometricEnabled) return BiometricReadiness.unavailable;
    if (!await _biometrics.isAvailable) return BiometricReadiness.unavailable;
    final kind = await _biometrics.resolveKind();
    return BiometricReadiness(ready: true, kind: kind);
  }
}
