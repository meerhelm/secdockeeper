import '../../security/lock_settings.dart';

class SettingsState {
  const SettingsState({
    this.panicAction = PanicAction.lockout,
    this.busy = false,
    this.message,
  });

  final PanicAction panicAction;
  final bool busy;
  final String? message;

  SettingsState copyWith({
    PanicAction? panicAction,
    bool? busy,
    String? message,
    bool clearMessage = false,
  }) {
    return SettingsState(
      panicAction: panicAction ?? this.panicAction,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.panicAction == panicAction &&
      other.busy == busy &&
      other.message == message;

  @override
  int get hashCode => Object.hash(panicAction, busy, message);
}
