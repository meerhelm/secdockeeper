import '../lock_settings.dart';

class EnableBiometricsUseCase {
  EnableBiometricsUseCase(this._lockSettings);

  final LockSettings _lockSettings;

  Future<void> call(String masterPassword) =>
      _lockSettings.enableBiometric(masterPassword);
}
