import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  bool _biometricEnabled = false;
  int _autoLockSeconds = 60;
  bool _loaded = false;

  bool get biometricEnabled => _biometricEnabled;
  int get autoLockSeconds => _autoLockSeconds;
  bool get loaded => _loaded;

  Future<void> load() async {
    final b = await _storage.read(key: _kBiometricEnabled);
    final s = await _storage.read(key: _kAutoLockSeconds);
    _biometricEnabled = b == 'true';
    _autoLockSeconds = int.tryParse(s ?? '') ?? 60;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    _autoLockSeconds = seconds;
    await _storage.write(key: _kAutoLockSeconds, value: seconds.toString());
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
    _biometricEnabled = false;
    _autoLockSeconds = 60;
    notifyListeners();
  }
}
