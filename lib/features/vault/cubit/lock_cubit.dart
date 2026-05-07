import 'package:flutter_bloc/flutter_bloc.dart';

import '../../security/lock_settings.dart';
import '../../security/usecases/biometric_unlock.dart';
import '../../security/usecases/is_biometric_unlock_ready.dart';
import '../../security/usecases/register_failed_unlock.dart';
import '../usecases/unlock_vault.dart';
import 'lock_state.dart';

class LockCubit extends Cubit<VaultLockState> {
  LockCubit({
    required UnlockVaultUseCase unlockVault,
    required BiometricUnlockUseCase biometricUnlock,
    required IsBiometricUnlockReadyUseCase isBiometricReady,
    required RegisterFailedUnlockUseCase registerFailedUnlock,
    required LockSettings lockSettings,
  })  : _unlockVault = unlockVault,
        _biometricUnlock = biometricUnlock,
        _isBiometricReady = isBiometricReady,
        _registerFailedUnlock = registerFailedUnlock,
        _lockSettings = lockSettings,
        super(const VaultLockState());

  final UnlockVaultUseCase _unlockVault;
  final BiometricUnlockUseCase _biometricUnlock;
  final IsBiometricUnlockReadyUseCase _isBiometricReady;
  final RegisterFailedUnlockUseCase _registerFailedUnlock;
  final LockSettings _lockSettings;

  Future<void> init() async {
    final readiness = await _isBiometricReady();
    if (isClosed) return;

    final until = _lockSettings.lockedUntil;
    final coolingDown = until != null && DateTime.now().isBefore(until);
    // Biometric is suppressed after any wrong password and stays suppressed
    // until a correct password unlocks — prevents an attacker from pivoting
    // back to the biometric prompt after probing the password field.
    final panicSuppressed = _lockSettings.failedAttempts > 0;

    emit(state.copyWith(
      biometricAvailable: readiness.ready && !panicSuppressed,
      biometricKind: readiness.kind,
      lockedUntil: coolingDown ? until : null,
      clearLockedUntil: !coolingDown,
    ));
  }

  /// Called by the lock screen when its countdown timer hits zero. Inputs
  /// re-enable but the failed-attempt counter persists — the next wrong
  /// password counts toward the next escalation tier.
  void cooldownExpired() {
    if (isClosed) return;
    emit(state.copyWith(clearLockedUntil: true, clearError: true));
  }

  Future<void> submit(String password) async {
    if (state.isCoolingDown) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final ok = await _unlockVault(password);
      if (ok) {
        await _lockSettings.resetPanicCounter();
        // success: vault notifies → router redirects → cubit closes.
        return;
      }
      await _handleFailure();
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed to unlock: $e'));
      }
    }
  }

  Future<void> _handleFailure() async {
    final outcome = await _registerFailedUnlock();
    if (isClosed) return;
    switch (outcome) {
      case FailedUnlockRecorded():
        final remaining =
            LockSettings.panicThreshold - outcome.failedAttempts;
        emit(state.copyWith(
          busy: false,
          biometricAvailable: false,
          error: remaining == 1
              ? 'Incorrect password. 1 attempt left before lockout.'
              : 'Incorrect password. $remaining attempts left.',
        ));
      case FailedUnlockCooldown():
        emit(state.copyWith(
          busy: false,
          biometricAvailable: false,
          lockedUntil: outcome.until,
          clearError: true,
        ));
      case FailedUnlockWiped():
        // Router redirects to onboarding via VaultService notification.
        break;
    }
  }

  Future<void> tryBiometric() async {
    if (state.busy || state.isCoolingDown || !state.biometricAvailable) return;
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _biometricUnlock();
    if (isClosed) return;
    switch (result) {
      case BiometricUnlockSuccess():
        await _lockSettings.resetPanicCounter();
        // Router redirects.
        break;
      case BiometricUnlockCancelled():
        emit(state.copyWith(busy: false));
      case BiometricUnlockNoStoredPassword():
        emit(state.copyWith(
          busy: false,
          biometricAvailable: false,
          error: 'Stored credentials missing. Enter password.',
        ));
      case BiometricUnlockInvalidStoredPassword():
        emit(state.copyWith(
          busy: false,
          biometricAvailable: false,
          error: 'Stored password no longer valid. Enter manually.',
        ));
      case BiometricUnlockFailed(:final error):
        emit(state.copyWith(busy: false, error: 'Biometric failed: $error'));
    }
  }
}
