import '../../security/lock_settings.dart';

class SettingsState {
  const SettingsState({
    this.panicAction = PanicAction.lockout,
    this.biometricAvailable = false,
    this.biometricEnabled = false,
    this.busy = false,
    this.message,
    this.error,
  });

  final PanicAction panicAction;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final bool busy;
  final String? message;
  final String? error;

  SettingsState copyWith({
    PanicAction? panicAction,
    bool? biometricAvailable,
    bool? biometricEnabled,
    bool? busy,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return SettingsState(
      panicAction: panicAction ?? this.panicAction,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.panicAction == panicAction &&
      other.biometricAvailable == biometricAvailable &&
      other.biometricEnabled == biometricEnabled &&
      other.busy == busy &&
      other.message == message &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
        panicAction,
        biometricAvailable,
        biometricEnabled,
        busy,
        message,
        error,
      );
}
