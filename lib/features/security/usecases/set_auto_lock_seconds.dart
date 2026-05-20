import '../lock_settings.dart';

class SetAutoLockSecondsUseCase {
  SetAutoLockSecondsUseCase(this._lockSettings);

  final LockSettings _lockSettings;

  Future<void> call(int seconds) =>
      _lockSettings.setAutoLockSeconds(seconds);
}
