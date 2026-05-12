import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../backup/usecases/export_backup.dart';
import '../../security/lock_settings.dart';
import '../../security/usecases/disable_biometrics.dart';
import '../../security/usecases/enable_biometrics.dart';
import '../../security/usecases/is_biometric_available.dart';
import '../../security/usecases/set_panic_action.dart';
import '../../sharing/usecases/import_shared_package.dart';
import '../../vault/usecases/destroy_vault.dart';
import '../../vault/usecases/rotate_vault_key.dart';
import '../../vault/usecases/verify_master_password.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required LockSettings lockSettings,
    required SetPanicActionUseCase setPanicAction,
    required ImportSharedPackageUseCase importSharedPackage,
    required ExportBackupUseCase exportBackup,
    required RotateVaultKeyUseCase rotateVaultKey,
    required DestroyVaultUseCase destroyVault,
    required IsBiometricAvailableUseCase isBiometricAvailable,
    required EnableBiometricsUseCase enableBiometrics,
    required DisableBiometricsUseCase disableBiometrics,
    required VerifyMasterPasswordUseCase verifyMasterPassword,
  })  : _lockSettings = lockSettings,
        _setPanicAction = setPanicAction,
        _importSharedPackage = importSharedPackage,
        _exportBackup = exportBackup,
        _rotateVaultKey = rotateVaultKey,
        _destroyVault = destroyVault,
        _isBiometricAvailable = isBiometricAvailable,
        _enableBiometrics = enableBiometrics,
        _disableBiometrics = disableBiometrics,
        _verifyMasterPassword = verifyMasterPassword,
        super(SettingsState(
          panicAction: lockSettings.panicAction,
          biometricEnabled: lockSettings.biometricEnabled,
        )) {
    _resolveBiometricAvailability();
    _lockSettings.addListener(_onLockSettingsChanged);
  }

  final LockSettings _lockSettings;
  final SetPanicActionUseCase _setPanicAction;
  final ImportSharedPackageUseCase _importSharedPackage;
  final ExportBackupUseCase _exportBackup;
  final RotateVaultKeyUseCase _rotateVaultKey;
  final DestroyVaultUseCase _destroyVault;
  final IsBiometricAvailableUseCase _isBiometricAvailable;
  final EnableBiometricsUseCase _enableBiometrics;
  final DisableBiometricsUseCase _disableBiometrics;
  final VerifyMasterPasswordUseCase _verifyMasterPassword;

  Future<void> _resolveBiometricAvailability() async {
    final available = await _isBiometricAvailable();
    if (isClosed) return;
    emit(state.copyWith(biometricAvailable: available));
  }

  void _onLockSettingsChanged() {
    if (isClosed) return;
    emit(state.copyWith(
      panicAction: _lockSettings.panicAction,
      biometricEnabled: _lockSettings.biometricEnabled,
    ));
  }

  void refresh() {
    emit(state.copyWith(
      panicAction: _lockSettings.panicAction,
      biometricEnabled: _lockSettings.biometricEnabled,
    ));
  }

  Future<void> setPanicAction(PanicAction action) async {
    if (state.panicAction == action) return;
    emit(state.copyWith(busy: true, clearMessage: true, clearError: true));
    await _setPanicAction(action);
    if (isClosed) return;
    emit(state.copyWith(
      panicAction: action,
      busy: false,
      message: action == PanicAction.wipe
          ? 'Wipe-on-panic enabled.'
          : 'Lockout-on-panic enabled.',
    ));
  }

  Future<bool> enableBiometric(String masterPassword) async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    final ok = await _verifyMasterPassword(masterPassword);
    if (!ok) {
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          error: 'Incorrect master password.',
        ));
      }
      return false;
    }
    await _enableBiometrics(masterPassword);
    if (!isClosed) {
      emit(state.copyWith(
        busy: false,
        biometricEnabled: true,
        message: 'Biometric login enabled.',
      ));
    }
    return true;
  }

  Future<void> disableBiometric() async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    await _disableBiometrics();
    if (!isClosed) {
      emit(state.copyWith(
        busy: false,
        biometricEnabled: false,
        message: 'Biometric login disabled.',
      ));
    }
  }

  Future<void> importSharedPackage({
    required File blobFile,
    required File keyFile,
  }) async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    try {
      await _importSharedPackage(blobFile: blobFile, keyFile: keyFile);
      if (!isClosed) {
        emit(state.copyWith(busy: false, message: 'Shared document imported'));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Import failed: $e'));
      }
    }
  }

  Future<void> exportBackup() async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    try {
      final archive = await _exportBackup();
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          message: 'Backup ready: ${archive.file.path.split('/').last}',
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Backup failed: $e'));
      }
    }
  }

  Future<void> changeMasterPassword(String newPassword) async {
    emit(state.copyWith(busy: true, clearError: true, clearMessage: true));
    try {
      await _rotateVaultKey(newPassword);
      if (!isClosed) {
        emit(state.copyWith(
          busy: false,
          message: 'Master password changed successfully',
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: 'Failed to change password: $e'));
      }
    }
  }

  Future<void> destroyVault() async {
    await _destroyVault();
    // Vault state changes → router redirects to onboarding.
  }

  @override
  Future<void> close() async {
    _lockSettings.removeListener(_onLockSettingsChanged);
    return super.close();
  }
}
