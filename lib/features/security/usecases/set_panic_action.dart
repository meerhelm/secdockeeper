import '../lock_settings.dart';

class SetPanicActionUseCase {
  SetPanicActionUseCase(this._lockSettings);

  final LockSettings _lockSettings;

  Future<void> call(PanicAction action) => _lockSettings.setPanicAction(action);
}
