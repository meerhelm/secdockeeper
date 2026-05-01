import 'package:flutter_bloc/flutter_bloc.dart';

import '../../security/usecases/biometric_unlock.dart';
import '../../security/usecases/is_biometric_unlock_ready.dart';
import '../usecases/unlock_vault.dart';
import 'lock_state.dart';

class LockCubit extends Cubit<VaultLockState> {
  LockCubit({
    required UnlockVaultUseCase unlockVault,
    required BiometricUnlockUseCase biometricUnlock,
    required IsBiometricUnlockReadyUseCase isBiometricReady,
  })  : _unlockVault = unlockVault,
        _biometricUnlock = biometricUnlock,
        _isBiometricReady = isBiometricReady,
        super(const VaultLockState());

  final UnlockVaultUseCase _unlockVault;
  final BiometricUnlockUseCase _biometricUnlock;
  final IsBiometricUnlockReadyUseCase _isBiometricReady;

  Future<void> init() async {
    final ready = await _isBiometricReady();
    if (isClosed) return;
    emit(state.copyWith(biometricAvailable: ready));
    if (ready) await tryBiometric();
  }

  Future<void> submit(String password) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final ok = await _unlockVault(password);
      if (!ok && !isClosed) {
        emit(state.copyWith(busy: false, error: 'Incorrect password'));
      }
      // success: vault notifies → router redirects → cubit closes.
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed to unlock: $e'));
      }
    }
  }

  Future<void> tryBiometric() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _biometricUnlock();
    if (isClosed) return;
    switch (result) {
      case BiometricUnlockSuccess():
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
