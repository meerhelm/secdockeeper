import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/biometric_service.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/security/usecases/is_biometric_unlock_ready.dart';

class _MockBiometricService extends Mock implements BiometricService {}

class _MockLockSettings extends Mock implements LockSettings {}

void main() {
  late _MockBiometricService biometrics;
  late _MockLockSettings lockSettings;
  late IsBiometricUnlockReadyUseCase useCase;

  setUp(() {
    biometrics = _MockBiometricService();
    lockSettings = _MockLockSettings();
    useCase = IsBiometricUnlockReadyUseCase(
      biometrics: biometrics,
      lockSettings: lockSettings,
    );
  });

  test('returns false when biometric is not enabled in settings', () async {
    when(() => lockSettings.biometricEnabled).thenReturn(false);

    expect(await useCase(), isFalse);
    verifyNever(() => biometrics.isAvailable);
  });

  test('returns true when enabled and device supports it', () async {
    when(() => lockSettings.biometricEnabled).thenReturn(true);
    when(() => biometrics.isAvailable).thenAnswer((_) async => true);

    expect(await useCase(), isTrue);
  });

  test('returns false when enabled but device does not support it', () async {
    when(() => lockSettings.biometricEnabled).thenReturn(true);
    when(() => biometrics.isAvailable).thenAnswer((_) async => false);

    expect(await useCase(), isFalse);
  });
}
