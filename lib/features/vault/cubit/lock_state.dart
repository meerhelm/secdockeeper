class VaultLockState {
  const VaultLockState({
    this.busy = false,
    this.biometricAvailable = false,
    this.error,
  });

  final bool busy;
  final bool biometricAvailable;
  final String? error;

  VaultLockState copyWith({
    bool? busy,
    bool? biometricAvailable,
    String? error,
    bool clearError = false,
  }) {
    return VaultLockState(
      busy: busy ?? this.busy,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VaultLockState &&
      other.busy == busy &&
      other.biometricAvailable == biometricAvailable &&
      other.error == error;

  @override
  int get hashCode => Object.hash(busy, biometricAvailable, error);
}
