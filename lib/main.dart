import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/paths.dart';
import 'features/security/lock_settings.dart';
import 'features/vault/vault_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await VaultPaths.resolve();
  final vault = VaultService(paths: paths);
  final lockSettings = LockSettings();
  await lockSettings.load();

  // iOS Keychain (and Android EncryptedSharedPreferences with auto-backup)
  // can outlive the app's filesystem sandbox. If the vault file was wiped on
  // uninstall but the Keychain entries survived, panic counter / lockout /
  // stored biometric password are all orphans pointing at a vault that no
  // longer exists — clear them so the user gets a clean onboarding.
  if (vault.state == VaultState.uninitialized && _hasResidualSecureState(lockSettings)) {
    log.w('orphan secure storage detected after uninstall — clearing');
    await lockSettings.clearAll();
  }

  final services = AppServices(
    vault: vault,
    paths: paths,
    lockSettings: lockSettings,
  );
  services.autoLock.start();
  runApp(SecDockKeeperApp(services: services));
}

bool _hasResidualSecureState(LockSettings s) =>
    s.biometricEnabled ||
    s.failedAttempts > 0 ||
    s.lockedUntil != null;
