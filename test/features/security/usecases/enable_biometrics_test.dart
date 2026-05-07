import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/security/usecases/enable_biometrics.dart';

class _MockLockSettings extends Mock implements LockSettings {}

void main() {
  late _MockLockSettings lockSettings;
  late EnableBiometricsUseCase useCase;

  setUp(() {
    lockSettings = _MockLockSettings();
    useCase = EnableBiometricsUseCase(lockSettings);
  });

  test('forwards password to LockSettings.enableBiometric', () async {
    when(() => lockSettings.enableBiometric(any())).thenAnswer((_) async {});

    await useCase('master-password');

    verify(() => lockSettings.enableBiometric('master-password')).called(1);
  });
}
