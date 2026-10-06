import 'package:flutter/widgets.dart';

import '../vault/vault_service.dart';
import 'lock_settings.dart';

class AutoLockController with WidgetsBindingObserver {
  AutoLockController({
    required this.vault,
    required this.settings,
    required this.wipeTemp,
  });

  final VaultService vault;
  final LockSettings settings;

  /// Removes decrypted temp files. Runs on resume rather than on pause: with
  /// an immediate lock the app is paused precisely because a system viewer
  /// is reading one of those files.
  final Future<void> Function() wipeTemp;

  DateTime? _backgroundedAt;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        if (vault.state != VaultState.unlocked) return;
        _backgroundedAt ??= DateTime.now();
        if (settings.autoLockSeconds == 0) {
          vault.lock();
        }
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      case AppLifecycleState.detached:
        _backgroundedAt = null;
        break;
    }
  }

  Future<void> _onResumed() async {
    final ts = _backgroundedAt;
    _backgroundedAt = null;
    if (ts == null) return;
    if (vault.state == VaultState.unlocked) {
      final elapsed = DateTime.now().difference(ts).inSeconds;
      if (elapsed < settings.autoLockSeconds) return;
      await vault.lock();
    }
    await wipeTemp();
  }
}
