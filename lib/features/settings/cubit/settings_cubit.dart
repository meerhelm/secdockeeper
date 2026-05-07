import 'package:flutter_bloc/flutter_bloc.dart';

import '../../security/lock_settings.dart';
import '../../security/usecases/set_panic_action.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required LockSettings lockSettings,
    required SetPanicActionUseCase setPanicAction,
  })  : _lockSettings = lockSettings,
        _setPanicAction = setPanicAction,
        super(SettingsState(panicAction: lockSettings.panicAction));

  final LockSettings _lockSettings;
  final SetPanicActionUseCase _setPanicAction;

  void refresh() {
    emit(state.copyWith(panicAction: _lockSettings.panicAction));
  }

  Future<void> setPanicAction(PanicAction action) async {
    if (state.panicAction == action) return;
    emit(state.copyWith(busy: true, clearMessage: true));
    await _setPanicAction(action);
    if (isClosed) return;
    emit(state.copyWith(
      panicAction: action,
      busy: false,
      message: action == PanicAction.wipe
          ? 'Wipe-on-panic enabled.'
          : 'Lockout-on-panic enabled.',
    ));
  }
}
