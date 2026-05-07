import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/security/usecases/set_panic_action.dart';

class _MockLockSettings extends Mock implements LockSettings {}

void main() {
  setUpAll(() {
    registerFallbackValue(PanicAction.lockout);
  });

  test('forwards action to LockSettings.setPanicAction', () async {
    final settings = _MockLockSettings();
    when(() => settings.setPanicAction(any())).thenAnswer((_) async {});

    await SetPanicActionUseCase(settings)(PanicAction.wipe);

    verify(() => settings.setPanicAction(PanicAction.wipe)).called(1);
  });
}
