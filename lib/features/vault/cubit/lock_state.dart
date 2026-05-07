import '../../security/biometric_service.dart';

class VaultLockState {
  const VaultLockState({
    this.busy = false,
    this.biometricAvailable = false,
    this.biometricKind = BiometricKind.generic,
    this.error,
    this.lockedUntil,
  });

  final bool busy;
  final bool biometricAvailable;
  final BiometricKind biometricKind;
  final String? error;

  /// When non-null and in the future, all unlock input is blocked. The lock
  /// screen displays a countdown until this timestamp.
  final DateTime? lockedUntil;

  bool get isCoolingDown =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  VaultLockState copyWith({
    bool? busy,
    bool? biometricAvailable,
    BiometricKind? biometricKind,
    String? error,
    DateTime? lockedUntil,
    bool clearError = false,
    bool clearLockedUntil = false,
  }) {
    return VaultLockState(
      busy: busy ?? this.busy,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      biometricKind: biometricKind ?? this.biometricKind,
      error: clearError ? null : (error ?? this.error),
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VaultLockState &&
      other.busy == busy &&
      other.biometricAvailable == biometricAvailable &&
      other.biometricKind == biometricKind &&
      other.error == error &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode =>
      Object.hash(busy, biometricAvailable, biometricKind, error, lockedUntil);
}
