import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../backup/usecases/restore_backup.dart';
import '../../security/lock_settings.dart';
import '../../security/usecases/enable_biometrics.dart';
import '../../security/usecases/is_biometric_available.dart';
import '../../security/usecases/set_panic_action.dart';
import '../../vault/usecases/initialize_vault.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required InitializeVaultUseCase initializeVault,
    required IsBiometricAvailableUseCase isBiometricAvailable,
    required EnableBiometricsUseCase enableBiometrics,
    required SetPanicActionUseCase setPanicAction,
    required RestoreBackupUseCase restoreBackup,
  })  : _initializeVault = initializeVault,
        _isBiometricAvailable = isBiometricAvailable,
        _enableBiometrics = enableBiometrics,
        _setPanicAction = setPanicAction,
        _restoreBackup = restoreBackup,
        super(const OnboardingState());

  final InitializeVaultUseCase _initializeVault;
  final IsBiometricAvailableUseCase _isBiometricAvailable;
  final EnableBiometricsUseCase _enableBiometrics;
  final SetPanicActionUseCase _setPanicAction;
  final RestoreBackupUseCase _restoreBackup;

  String? _pendingPassword;
  bool _pendingBiometric = false;

  Future<void> create(String password) async {
    log.i('[onboarding] create() called, length=${password.length}');
    emit(state.copyWith(busy: true, clearError: true));
    try {
      _pendingPassword = password;
      _pendingBiometric = false;
      final available = await _isBiometricAvailable();
      log.d('[onboarding] biometric available=$available');
      if (isClosed) return;
      if (available) {
        emit(state.copyWith(busy: false, askBiometric: true));
      } else {
        emit(state.copyWith(busy: false, askPanic: true));
      }
    } catch (e, st) {
      log.e('[onboarding] create failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          error: 'Failed to initialize vault: $e',
        ));
      }
    }
  }

  Future<void> resolveBiometric({required bool accepted}) async {
    log.d('[onboarding] resolveBiometric(accepted=$accepted)');
    _pendingBiometric = accepted;
    emit(state.copyWith(askBiometric: false, askPanic: true));
  }

  Future<void> resolvePanic(PanicAction action) async {
    log.i('[onboarding] resolvePanic($action)');
    final pwd = _pendingPassword;
    final biometric = _pendingBiometric;
    _pendingPassword = null;
    _pendingBiometric = false;
    if (pwd == null) {
      log.w('[onboarding] resolvePanic: no pending password — bailing');
      emit(state.copyWith(askPanic: false));
      return;
    }
    emit(state.copyWith(busy: true, askPanic: false, clearError: true));
    try {
      await _setPanicAction(action);
      log.d('[onboarding] panic action saved, initializing vault');
      await _initializeVault(pwd);
      if (biometric) {
        await _enableBiometrics(pwd);
      }
      log.i('[onboarding] vault initialized');
      // Router redirect imminent; do not emit further.
    } catch (e, st) {
      log.e('[onboarding] vault init failed', error: e, stackTrace: st);
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
      log.e('[onboarding] restore failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Restore failed: $e'));
      }
    }
  }
}
