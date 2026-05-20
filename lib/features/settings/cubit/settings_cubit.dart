import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/crypto/kdf.dart';
import '../../../core/logging/app_logger.dart';
import '../../backup/usecases/export_backup.dart';
import '../../security/lock_settings.dart';
import '../../security/usecases/disable_biometrics.dart';
import '../../security/usecases/enable_biometrics.dart';
import '../../security/usecases/is_biometric_available.dart';
import '../../security/usecases/set_auto_lock_seconds.dart';
import '../../security/usecases/set_panic_action.dart';
import '../../security/usecases/set_theme_mode.dart';
import '../../sharing/usecases/import_shared_package.dart';
import '../../vault/usecases/destroy_vault.dart';
import '../../vault/usecases/get_vault_kdf_profile.dart';
import '../../vault/usecases/harden_vault.dart';
import '../../vault/usecases/rotate_vault_key.dart';
import '../../vault/usecases/verify_master_password.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required LockSettings lockSettings,
    required SetPanicActionUseCase setPanicAction,
    required SetAutoLockSecondsUseCase setAutoLockSeconds,
    required SetThemeModeUseCase setThemeMode,
    required ImportSharedPackageUseCase importSharedPackage,
    required ExportBackupUseCase exportBackup,
    required RotateVaultKeyUseCase rotateVaultKey,
    required DestroyVaultUseCase destroyVault,
    required IsBiometricAvailableUseCase isBiometricAvailable,
    required EnableBiometricsUseCase enableBiometrics,
    required DisableBiometricsUseCase disableBiometrics,
    required VerifyMasterPasswordUseCase verifyMasterPassword,
    required GetVaultKdfProfileUseCase getVaultKdfProfile,
    required HardenVaultUseCase hardenVault,
  })  : _lockSettings = lockSettings,
        _hardenVault = hardenVault,
        _setPanicAction = setPanicAction,
        _setAutoLockSeconds = setAutoLockSeconds,
        _setThemeMode = setThemeMode,
        _importSharedPackage = importSharedPackage,
        _exportBackup = exportBackup,
        _rotateVaultKey = rotateVaultKey,
        _destroyVault = destroyVault,
        _isBiometricAvailable = isBiometricAvailable,
        _enableBiometrics = enableBiometrics,
        _disableBiometrics = disableBiometrics,
        _verifyMasterPassword = verifyMasterPassword,
        _getVaultKdfProfile = getVaultKdfProfile,
        super(SettingsState(
          panicAction: lockSettings.panicAction,
          biometricEnabled: lockSettings.biometricEnabled,
          autoLockSeconds: lockSettings.autoLockSeconds,
          themeMode: lockSettings.themeMode,
        )) {
    _resolveBiometricAvailability();
    _resolveKdfProfile();
    _lockSettings.addListener(_onLockSettingsChanged);
  }

  final LockSettings _lockSettings;
  final SetPanicActionUseCase _setPanicAction;
  final SetAutoLockSecondsUseCase _setAutoLockSeconds;
  final SetThemeModeUseCase _setThemeMode;
  final ImportSharedPackageUseCase _importSharedPackage;
  final ExportBackupUseCase _exportBackup;
  final RotateVaultKeyUseCase _rotateVaultKey;
  final DestroyVaultUseCase _destroyVault;
  final IsBiometricAvailableUseCase _isBiometricAvailable;
  final EnableBiometricsUseCase _enableBiometrics;
  final DisableBiometricsUseCase _disableBiometrics;
  final VerifyMasterPasswordUseCase _verifyMasterPassword;
  final GetVaultKdfProfileUseCase _getVaultKdfProfile;
  final HardenVaultUseCase _hardenVault;

  Future<void> _resolveBiometricAvailability() async {
    final available = await _isBiometricAvailable();
    if (isClosed) return;
    emit(state.copyWith(biometricAvailable: available));
  }

  Future<void> _resolveKdfProfile() async {
    try {
      final status = await _getVaultKdfProfile();
      if (isClosed) return;
      emit(state.copyWith(
        kdfProfile: status.profile,
        kdfBelowDefault: status.belowDefault,
      ));
    } catch (e, st) {
      log.w('[settings] failed to resolve kdf profile',
          error: e, stackTrace: st);
    }
  }

  void _onLockSettingsChanged() {
    if (isClosed) return;
    emit(state.copyWith(
      panicAction: _lockSettings.panicAction,
      biometricEnabled: _lockSettings.biometricEnabled,
      autoLockSeconds: _lockSettings.autoLockSeconds,
      themeMode: _lockSettings.themeMode,
    ));
  }

  void refresh() {
    emit(state.copyWith(
      panicAction: _lockSettings.panicAction,
      biometricEnabled: _lockSettings.biometricEnabled,
      autoLockSeconds: _lockSettings.autoLockSeconds,
      themeMode: _lockSettings.themeMode,
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

  Future<void> setAutoLockSeconds(int seconds) async {
    if (state.autoLockSeconds == seconds) return;
    emit(state.copyWith(busy: true, clearMessage: true, clearError: true));
    await _setAutoLockSeconds(seconds);
    if (isClosed) return;
    emit(state.copyWith(
      autoLockSeconds: seconds,
      busy: false,
      message: 'Auto-lock updated.',
    ));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;
    emit(state.copyWith(busy: true, clearMessage: true, clearError: true));
    await _setThemeMode(mode);
    if (isClosed) return;
    emit(state.copyWith(
      themeMode: mode,
      busy: false,
      message: 'Theme updated.',
    ));
  }

  /// Returns the master password stored for biometric unlock, if any —
  /// lets the UI skip the password prompt when biometrics are enabled.
  Future<String?> readStoredMasterPassword() =>
      _lockSettings.readStoredPassword();

  /// Re-derives the KEK under [targetParams] and re-keys the vault. The
  /// usecase rejects downgrades and equal-strength rotations internally; we
  /// just forward the call and surface results. The password is verified
  /// inside the usecase before any state mutation.
  Future<bool> hardenTo({
    required KdfParams targetParams,
    required String currentPassword,
  }) async {
    emit(state.copyWith(
      hardening: true,
      busy: true,
      clearError: true,
      clearMessage: true,
    ));
    try {
      await _hardenVault(
        currentPassword: currentPassword,
        targetParams: targetParams,
      );
      if (isClosed) return true;
      final newProfile = KdfProfile.fromParams(targetParams);
      final defaults = KdfParams.defaultParams;
      final belowDefault = targetParams.memory < defaults.memory ||
          targetParams.iterations < defaults.iterations ||
          targetParams.parallelism < defaults.parallelism;
      emit(state.copyWith(
        kdfProfile: newProfile,
        kdfBelowDefault: belowDefault,
        hardening: false,
        busy: false,
        message: 'Vault hardened — Argon2id strengthened.',
      ));
      return true;
    } on HardenVaultError catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          hardening: false,
          busy: false,
          error: e.message,
        ));
      }
      return false;
    } catch (e, st) {
      log.e('[settings] harden vault failed', error: e, stackTrace: st);
      if (!isClosed) {
        emit(state.copyWith(
          hardening: false,
          busy: false,
          error: 'Hardening failed: $e',
        ));
      }
      return false;
    }
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
    } catch (e, st) {
      log.e('[settings] import shared package failed', error: e, stackTrace: st);
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
    } catch (e, st) {
      log.e('[settings] backup export failed', error: e, stackTrace: st);
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
    } catch (e, st) {
      log.e('[settings] master password rotation failed',
          error: e, stackTrace: st);
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
