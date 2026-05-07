import '../../vault/usecases/destroy_vault.dart';
import '../lock_settings.dart';

sealed class FailedUnlockOutcome {
  const FailedUnlockOutcome();
}

/// Counter incremented but no panic step triggered.
class FailedUnlockRecorded extends FailedUnlockOutcome {
  const FailedUnlockRecorded(this.failedAttempts);
  final int failedAttempts;
}

/// Cooldown started — UI must block input until [until].
class FailedUnlockCooldown extends FailedUnlockOutcome {
  const FailedUnlockCooldown({
    required this.failedAttempts,
    required this.until,
  });
  final int failedAttempts;
  final DateTime until;
}

/// Vault was wiped — router will redirect to onboarding.
class FailedUnlockWiped extends FailedUnlockOutcome {
  const FailedUnlockWiped();
}

/// Increments the failed-attempt counter and applies the configured panic
/// action when the counter hits a multiple of [LockSettings.panicThreshold].
///
/// - [PanicAction.lockout]: starts an escalating cooldown (10m → 30m → 1h → 1d).
/// - [PanicAction.wipe]: silently destroys the vault on the very first hit.
///
/// The counter persists across cooldowns and is only cleared by a successful
/// unlock (via [LockSettings.resetPanicCounter]).
class RegisterFailedUnlockUseCase {
  RegisterFailedUnlockUseCase({
    required LockSettings lockSettings,
    required DestroyVaultUseCase destroyVault,
    DateTime Function() now = DateTime.now,
  })  : _lockSettings = lockSettings,
        _destroyVault = destroyVault,
        _now = now;

  final LockSettings _lockSettings;
  final DestroyVaultUseCase _destroyVault;
  final DateTime Function() _now;

  Future<FailedUnlockOutcome> call() async {
    final next = _lockSettings.failedAttempts + 1;
    await _lockSettings.setFailedAttempts(next);

    final atThreshold = next % LockSettings.panicThreshold == 0;
    if (!atThreshold) {
      return FailedUnlockRecorded(next);
    }

    if (_lockSettings.panicAction == PanicAction.wipe) {
      await _destroyVault();
      return const FailedUnlockWiped();
    }

    final until = _now().add(LockSettings.lockoutDurationFor(next));
    await _lockSettings.setLockedUntil(until);
    return FailedUnlockCooldown(failedAttempts: next, until: until);
  }
}
