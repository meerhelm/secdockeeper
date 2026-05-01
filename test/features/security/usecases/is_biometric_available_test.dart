import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/security/biometric_service.dart';
import 'package:secdockeeper/features/security/usecases/is_biometric_available.dart';

class _MockBiometricService extends Mock implements BiometricService {}

void main() {
  late _MockBiometricService biometrics;
  late IsBiometricAvailableUseCase useCase;

  setUp(() {
    biometrics = _MockBiometricService();
    useCase = IsBiometricAvailableUseCase(biometrics);
  });

  test('returns true when biometrics are available', () async {
    when(() => biometrics.isAvailable).thenAnswer((_) async => true);
    expect(await useCase(), isTrue);
  });

  test('returns false when biometrics are unavailable', () async {
    when(() => biometrics.isAvailable).thenAnswer((_) async => false);
    expect(await useCase(), isFalse);
  });
}
