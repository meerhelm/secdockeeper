import '../../security/biometric_service.dart';

class VaultLockState {
  const VaultLockState({
    this.busy = false,
    this.biometricAvailable = false,
    this.biometricKind = BiometricKind.generic,
    this.error,
  });

  final bool busy;
  final bool biometricAvailable;
  final BiometricKind biometricKind;
  final String? error;

  VaultLockState copyWith({
    bool? busy,
    bool? biometricAvailable,
    BiometricKind? biometricKind,
    String? error,
    bool clearError = false,
  }) {
    return VaultLockState(
      busy: busy ?? this.busy,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricKind: biometricKind ?? this.biometricKind,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VaultLockState &&
      other.busy == busy &&
      other.biometricAvailable == biometricAvailable &&
      other.biometricKind == biometricKind &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(busy, biometricAvailable, biometricKind, error);
}
