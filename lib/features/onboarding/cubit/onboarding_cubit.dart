import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../backup/usecases/restore_backup.dart';
import '../../security/usecases/enable_biometrics.dart';
import '../../security/usecases/is_biometric_available.dart';
import '../../vault/usecases/initialize_vault.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required InitializeVaultUseCase initializeVault,
    required IsBiometricAvailableUseCase isBiometricAvailable,
    required EnableBiometricsUseCase enableBiometrics,
    required RestoreBackupUseCase restoreBackup,
  })  : _initializeVault = initializeVault,
        _isBiometricAvailable = isBiometricAvailable,
        _enableBiometrics = enableBiometrics,
        _restoreBackup = restoreBackup,
        super(const OnboardingState());

  final InitializeVaultUseCase _initializeVault;
  final IsBiometricAvailableUseCase _isBiometricAvailable;
  final EnableBiometricsUseCase _enableBiometrics;
  final RestoreBackupUseCase _restoreBackup;

  String? _pendingPassword;

  Future<void> create(String password) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final available = await _isBiometricAvailable();
      if (available) {
        _pendingPassword = password;
        emit(state.copyWith(busy: false, askBiometric: true));
        return;
      }
      await _initializeVault(password);
      // vault state -> unlocked, router redirects, cubit closes.
    } catch (e, st) {
      debugPrint('[onboarding] create failed: $e\n$st');
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          error: 'Failed to initialize vault: $e',
        ));
      }
    }
  }

  Future<void> resolveBiometric({required bool accepted}) async {
    final pwd = _pendingPassword;
    _pendingPassword = null;
    if (pwd == null) return;
    emit(state.copyWith(
      busy: true,
      askBiometric: false,
      clearError: true,
    ));
    try {
      await _initializeVault(pwd);
      if (accepted) {
        await _enableBiometrics(pwd);
      }
      // Router redirect imminent; do not emit further.
    } catch (e, st) {
      debugPrint('[onboarding] create failed: $e\n$st');
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          error: 'Failed to initialize vault: $e',
        ));
      }
    }
  }

  Future<void> restore(File archiveFile) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _restoreBackup(archiveFile);
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          restoreMessage:
              'Backup restored. Enter your master password.',
        ));
      }
    } catch (e, st) {
      debugPrint('[onboarding] restore failed: $e\n$st');
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Restore failed: $e'));
      }
    }
  }
}
