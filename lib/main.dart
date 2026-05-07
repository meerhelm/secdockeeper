import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'core/storage/paths.dart';
import 'features/security/lock_settings.dart';
import 'features/vault/vault_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await VaultPaths.resolve();
  final vault = VaultService(paths: paths);
  final lockSettings = LockSettings();
  await lockSettings.load();
  final services = AppServices(
    vault: vault,
    paths: paths,
    lockSettings: lockSettings,
  );
  services.autoLock.start();
  runApp(SecDockKeeperApp(services: services));
}
