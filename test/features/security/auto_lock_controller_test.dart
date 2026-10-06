import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/auto_lock_controller.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

class _MockLockSettings extends Mock implements LockSettings {}

void main() {
  late _MockVaultService vault;
  late _MockLockSettings settings;
  late AutoLockController controller;
  late int wipes;
  late VaultState state;

  setUp(() {
    vault = _MockVaultService();
    settings = _MockLockSettings();
    wipes = 0;
    state = VaultState.unlocked;
    when(() => vault.state).thenAnswer((_) => state);
    when(() => vault.lock()).thenAnswer((_) async => state = VaultState.locked);
    controller = AutoLockController(
      vault: vault,
      settings: settings,
      wipeTemp: () async => wipes++,
    );
  });

  test('immediate lock keeps temp files while paused, wipes them on resume',
      () async {
    when(() => settings.autoLockSeconds).thenReturn(0);

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await pumpEventQueue();
    verify(() => vault.lock()).called(1);
    expect(wipes, 0, reason: 'a system viewer may still be reading the file');

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(wipes, 1);
  });

  test('timed lock that has not elapsed neither locks nor wipes', () async {
    when(() => settings.autoLockSeconds).thenReturn(300);

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    verifyNever(() => vault.lock());
    expect(wipes, 0);
  });
}
