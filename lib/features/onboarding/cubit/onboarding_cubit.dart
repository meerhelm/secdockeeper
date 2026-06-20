import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../backup/usecases/restore_backup.dart';
import '../../security/lock_settings.dart';
import '../../security/usecases/enable_biometrics.dart';
import '../../security/usecases/is_biometric_available.dart';
import '../../security/usecases/set_panic_action.dart';
import '../../vault/usecases/create_hidden_vault.dart';
import '../../vault/usecases/initialize_vault.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required InitializeVaultUseCase initializeVault,
    required IsBiometricAvailableUseCase isBiometricAvailable,
    required EnableBiometricsUseCase enableBiometrics,
    required SetPanicActionUseCase setPanicAction,
    required RestoreBackupUseCase restoreBackup,
    required CreateHiddenVaultUseCase createHiddenVault,
  })  : _initializeVault = initializeVault,
        _isBiometricAvailable = isBiometricAvailable,
        _enableBiometrics = enableBiometrics,
        _setPanicAction = setPanicAction,
        _restoreBackup = restoreBackup,
        _createHiddenVault = createHiddenVault,
        super(const OnboardingState());

  final InitializeVaultUseCase _initializeVault;
  final IsBiometricAvailableUseCase _isBiometricAvailable;
  final EnableBiometricsUseCase _enableBiometrics;
  final SetPanicActionUseCase _setPanicAction;
  final RestoreBackupUseCase _restoreBackup;
  final CreateHiddenVaultUseCase _createHiddenVault;

  String? _pendingPassword;
  bool _pendingBiometric = false;
  PanicAction _pendingPanic = PanicAction.lockout;

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
    if (_pendingPassword == null) {
      log.w('[onboarding] resolvePanic: no pending password — bailing');
      emit(state.copyWith(askPanic: false));
      return;
    }
    // Defer vault creation until after the hidden-vault suggestion step.
    _pendingPanic = action;
    emit(state.copyWith(askPanic: false, askHidden: true));
  }

  /// Final onboarding step. [hiddenPassword] is the password for an optional
  /// hidden vault; null means the user skipped it. Creates the hidden vault
  /// first (independent of the primary), then initialises the primary vault,
  /// whose unlock triggers the router redirect.
  Future<void> resolveHidden({String? hiddenPassword}) async {
    log.i('[onboarding] resolveHidden(hidden=${hiddenPassword != null})');
    final pwd = _pendingPassword;
    final biometric = _pendingBiometric;
    final panic = _pendingPanic;
    _pendingPassword = null;
    _pendingBiometric = false;
    _pendingPanic = PanicAction.lockout;
    if (pwd == null) {
      emit(state.copyWith(askHidden: false));
      return;
    }
    emit(state.copyWith(busy: true, askHidden: false, clearError: true));
    try {
      await _setPanicAction(panic);
      if (hiddenPassword != null && hiddenPassword.isNotEmpty) {
        await _createHiddenVault(hiddenPassword);
      }
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
