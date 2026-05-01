import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/biometric_service.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/security/usecases/biometric_unlock.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockBiometricService extends Mock implements BiometricService {}

class _MockLockSettings extends Mock implements LockSettings {}

class _MockVaultService extends Mock implements VaultService {}

void main() {
  late _MockBiometricService biometrics;
  late _MockLockSettings lockSettings;
  late _MockVaultService vault;
  late BiometricUnlockUseCase useCase;

  setUp(() {
    biometrics = _MockBiometricService();
    lockSettings = _MockLockSettings();
    vault = _MockVaultService();
    useCase = BiometricUnlockUseCase(
      biometrics: biometrics,
      lockSettings: lockSettings,
      vault: vault,
    );
  });

  test('returns Cancelled when platform auth is denied', () async {
    when(() => biometrics.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => false);

    final result = await useCase();

    expect(result, isA<BiometricUnlockCancelled>());
    verifyNever(() => lockSettings.readStoredPassword());
    verifyNever(() => vault.unlock(any()));
  });

  test('returns NoStoredPassword when secure storage has no password', () async {
    when(() => biometrics.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => true);
    when(() => lockSettings.readStoredPassword()).thenAnswer((_) async => null);

    final result = await useCase();

    expect(result, isA<BiometricUnlockNoStoredPassword>());
    verifyNever(() => vault.unlock(any()));
  });

  test('returns InvalidStoredPassword and disables biometric when vault rejects',
      () async {
    when(() => biometrics.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => true);
    when(() => lockSettings.readStoredPassword())
        .thenAnswer((_) async => 'stale-pwd');
    when(() => vault.unlock(any())).thenAnswer((_) async => false);
    when(() => lockSettings.disableBiometric()).thenAnswer((_) async {});

    final result = await useCase();

    expect(result, isA<BiometricUnlockInvalidStoredPassword>());
    verify(() => lockSettings.disableBiometric()).called(1);
  });

  test('returns Success when stored password unlocks the vault', () async {
    when(() => biometrics.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => true);
    when(() => lockSettings.readStoredPassword())
        .thenAnswer((_) async => 'good-pwd');
    when(() => vault.unlock(any())).thenAnswer((_) async => true);

    final result = await useCase();

    expect(result, isA<BiometricUnlockSuccess>());
    verify(() => vault.unlock('good-pwd')).called(1);
    verifyNever(() => lockSettings.disableBiometric());
  });

  test('returns Failed when authenticate throws', () async {
    when(() => biometrics.authenticate(reason: any(named: 'reason')))
        .thenThrow(Exception('platform error'));

    final result = await useCase();

    expect(result, isA<BiometricUnlockFailed>());
    expect((result as BiometricUnlockFailed).error, isA<Exception>());
  });

  test('forwards reason to BiometricService.authenticate', () async {
    when(() => biometrics.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => false);

    await useCase(reason: 'Custom reason');

    verify(() => biometrics.authenticate(reason: 'Custom reason')).called(1);
  });
}
