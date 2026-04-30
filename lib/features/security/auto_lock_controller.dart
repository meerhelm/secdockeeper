import 'package:flutter/widgets.dart';

import '../vault/vault_service.dart';
import 'lock_settings.dart';

class AutoLockController with WidgetsBindingObserver {
  AutoLockController({required this.vault, required this.settings});

  final VaultService vault;
  final LockSettings settings;

  DateTime? _backgroundedAt;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (vault.state != VaultState.unlocked) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _backgroundedAt ??= DateTime.now();
        if (settings.autoLockSeconds == 0) {
          vault.lock();
        }
        break;
      case AppLifecycleState.resumed:
        final ts = _backgroundedAt;
        _backgroundedAt = null;
        if (ts == null) return;
        final elapsed = DateTime.now().difference(ts).inSeconds;
        if (elapsed >= settings.autoLockSeconds) {
          vault.lock();
        }
        break;
      case AppLifecycleState.detached:
        _backgroundedAt = null;
        break;
    }
  }
}
