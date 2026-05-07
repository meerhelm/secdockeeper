import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/security/usecases/register_failed_unlock.dart';
import 'package:secdockeeper/features/vault/usecases/destroy_vault.dart';

class _MockLockSettings extends Mock implements LockSettings {}

class _MockDestroyVault extends Mock implements DestroyVaultUseCase {}

void main() {
  late _MockLockSettings settings;
  late _MockDestroyVault destroyVault;
  final fakeNow = DateTime.utc(2026, 5, 7, 12);

  setUp(() {
    settings = _MockLockSettings();
    destroyVault = _MockDestroyVault();
    when(() => settings.setFailedAttempts(any())).thenAnswer((_) async {});
    when(() => settings.setLockedUntil(any())).thenAnswer((_) async {});
    when(() => destroyVault()).thenAnswer((_) async {});
  });

  RegisterFailedUnlockUseCase build() => RegisterFailedUnlockUseCase(
        lockSettings: settings,
        destroyVault: destroyVault,
        now: () => fakeNow,
      );

  group('lockout policy', () {
    setUp(() {
      when(() => settings.panicAction).thenReturn(PanicAction.lockout);
    });

    test('records non-threshold attempts without locking out', () async {
      when(() => settings.failedAttempts).thenReturn(0);

      final outcome = await build()();

      expect(outcome, isA<FailedUnlockRecorded>());
      verify(() => settings.setFailedAttempts(1)).called(1);
      verifyNever(() => settings.setLockedUntil(any()));
      verifyNever(() => destroyVault());
    });

    test('3rd consecutive fail starts a 10-minute cooldown', () async {
      when(() => settings.failedAttempts).thenReturn(2);

      final outcome = await build()();

      expect(outcome, isA<FailedUnlockCooldown>());
      final cooldown = outcome as FailedUnlockCooldown;
      expect(cooldown.failedAttempts, 3);
      expect(cooldown.until, fakeNow.add(const Duration(minutes: 10)));
      verify(() => settings.setFailedAttempts(3)).called(1);
      verify(() => settings.setLockedUntil(cooldown.until)).called(1);
      verifyNever(() => destroyVault());
    });

    test('6th fail escalates to 30 minutes', () async {
      when(() => settings.failedAttempts).thenReturn(5);
      final outcome = await build()() as FailedUnlockCooldown;
      expect(outcome.until, fakeNow.add(const Duration(minutes: 30)));
    });

    test('9th fail escalates to 1 hour', () async {
      when(() => settings.failedAttempts).thenReturn(8);
      final outcome = await build()() as FailedUnlockCooldown;
      expect(outcome.until, fakeNow.add(const Duration(hours: 1)));
    });

    test('12th fail and beyond cap at 1 day', () async {
      when(() => settings.failedAttempts).thenReturn(11);
      final outcome = await build()() as FailedUnlockCooldown;
      expect(outcome.until, fakeNow.add(const Duration(days: 1)));
    });

    test('attempts between thresholds (e.g. 4th, 5th) do not cooldown again',
        () async {
      when(() => settings.failedAttempts).thenReturn(3);
      final outcome = await build()();
      expect(outcome, isA<FailedUnlockRecorded>());
      verify(() => settings.setFailedAttempts(4)).called(1);
      verifyNever(() => settings.setLockedUntil(any()));
    });
  });

  group('wipe policy', () {
    setUp(() {
      when(() => settings.panicAction).thenReturn(PanicAction.wipe);
    });

    test('first two fails just increment, 3rd wipes', () async {
      when(() => settings.failedAttempts).thenReturn(0);
      expect(await build()(), isA<FailedUnlockRecorded>());
      verifyNever(() => destroyVault());

      when(() => settings.failedAttempts).thenReturn(2);
      expect(await build()(), isA<FailedUnlockWiped>());
      verify(() => destroyVault()).called(1);
      verifyNever(() => settings.setLockedUntil(any()));
    });
  });
}
