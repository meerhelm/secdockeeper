import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PanicAction { lockout, wipe }

class LockSettings extends ChangeNotifier {
  LockSettings({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kBiometricEnabled = 'sdk.biometric_enabled';
  static const _kAutoLockSeconds = 'sdk.auto_lock_seconds';
  static const _kStoredPassword = 'sdk.master_password';
  static const _kPanicAction = 'sdk.panic_action';
  static const _kFailedAttempts = 'sdk.panic_failed_attempts';
  static const _kLockedUntilMs = 'sdk.panic_locked_until_ms';

  /// Number of consecutive wrong-password attempts that trigger a panic step
  /// (escalating lockout) or a vault wipe.
  static const panicThreshold = 3;

  bool _biometricEnabled = false;
  int _autoLockSeconds = 60;
  PanicAction _panicAction = PanicAction.lockout;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  bool _loaded = false;

  bool get biometricEnabled => _biometricEnabled;
  int get autoLockSeconds => _autoLockSeconds;
  PanicAction get panicAction => _panicAction;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockedUntil => _lockedUntil;
  bool get loaded => _loaded;

  Future<void> load() async {
    final b = await _storage.read(key: _kBiometricEnabled);
    final s = await _storage.read(key: _kAutoLockSeconds);
    final pa = await _storage.read(key: _kPanicAction);
    final fa = await _storage.read(key: _kFailedAttempts);
    final lu = await _storage.read(key: _kLockedUntilMs);
    _biometricEnabled = b == 'true';
    _autoLockSeconds = int.tryParse(s ?? '') ?? 60;
    _panicAction = _decodePanicAction(pa);
    _failedAttempts = int.tryParse(fa ?? '') ?? 0;
    final luMs = int.tryParse(lu ?? '');
    _lockedUntil =
        luMs == null ? null : DateTime.fromMillisecondsSinceEpoch(luMs);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    await _storage.write(key: _kAutoLockSeconds, value: seconds.toString());
    notifyListeners();
  }

  Future<void> setPanicAction(PanicAction action) async {
    _panicAction = action;
    await _storage.write(key: _kPanicAction, value: _encodePanicAction(action));
    notifyListeners();
  }

  Future<void> setFailedAttempts(int count) async {
    _failedAttempts = count;
    await _storage.write(key: _kFailedAttempts, value: count.toString());
    notifyListeners();
  }

  Future<void> setLockedUntil(DateTime? until) async {
    _lockedUntil = until;
    if (until == null) {
      await _storage.delete(key: _kLockedUntilMs);
    } else {
      await _storage.write(
        key: _kLockedUntilMs,
        value: until.millisecondsSinceEpoch.toString(),
      );
    }
    notifyListeners();
  }

  /// Resets only the runtime panic counter + cooldown — leaves the user's
  /// chosen [panicAction] intact. Called after a successful unlock.
  Future<void> resetPanicCounter() async {
    _failedAttempts = 0;
    _lockedUntil = null;
    await _storage.delete(key: _kFailedAttempts);
    await _storage.delete(key: _kLockedUntilMs);
    notifyListeners();
  }

  Future<void> enableBiometric(String masterPassword) async {
    await _storage.write(key: _kStoredPassword, value: masterPassword);
    await _storage.write(key: _kBiometricEnabled, value: 'true');
    _biometricEnabled = true;
    notifyListeners();
  }

  Future<void> disableBiometric() async {
    await _storage.delete(key: _kStoredPassword);
    await _storage.write(key: _kBiometricEnabled, value: 'false');
    _biometricEnabled = false;
    notifyListeners();
  }

  Future<String?> readStoredPassword() async {
    if (!_biometricEnabled) return null;
    return _storage.read(key: _kStoredPassword);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _kBiometricEnabled);
    await _storage.delete(key: _kAutoLockSeconds);
    await _storage.delete(key: _kStoredPassword);
    await _storage.delete(key: _kPanicAction);
    await _storage.delete(key: _kFailedAttempts);
    await _storage.delete(key: _kLockedUntilMs);
    _biometricEnabled = false;
    _autoLockSeconds = 60;
    _panicAction = PanicAction.lockout;
    _failedAttempts = 0;
    _lockedUntil = null;
    notifyListeners();
  }

  /// Cooldown duration after the [failedAttempts]-th wrong attempt, when the
  /// counter is a multiple of [panicThreshold]. Caller is responsible for only
  /// invoking this on threshold hits. Ladder: 3→10m, 6→30m, 9→1h, 12+→1d.
  static Duration lockoutDurationFor(int failedAttempts) {
    final tier = (failedAttempts ~/ panicThreshold) - 1;
    return switch (tier) {
      <= 0 => const Duration(minutes: 10),
      1 => const Duration(minutes: 30),
      2 => const Duration(hours: 1),
      _ => const Duration(days: 1),
    };
  }
}

String _encodePanicAction(PanicAction action) => switch (action) {
      PanicAction.lockout => 'lockout',
      PanicAction.wipe => 'wipe',
    };

PanicAction _decodePanicAction(String? raw) => switch (raw) {
      'wipe' => PanicAction.wipe,
      _ => PanicAction.lockout,
    };
