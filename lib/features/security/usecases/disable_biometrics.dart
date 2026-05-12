import '../lock_settings.dart';

class DisableBiometricsUseCase {
  DisableBiometricsUseCase(this._lockSettings);

  final LockSettings _lockSettings;

  Future<void> call() => _lockSettings.disableBiometric();
}
