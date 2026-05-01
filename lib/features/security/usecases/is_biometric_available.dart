import '../biometric_service.dart';

class IsBiometricAvailableUseCase {
  IsBiometricAvailableUseCase(this._biometrics);

  final BiometricService _biometrics;

  Future<bool> call() => _biometrics.isAvailable;
}
