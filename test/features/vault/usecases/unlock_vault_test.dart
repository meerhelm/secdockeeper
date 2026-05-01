import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/vault/usecases/unlock_vault.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

void main() {
  late _MockVaultService vault;
  late UnlockVaultUseCase useCase;

  setUp(() {
    vault = _MockVaultService();
    useCase = UnlockVaultUseCase(vault);
  });

  test('returns true when VaultService.unlock succeeds', () async {
    when(() => vault.unlock(any())).thenAnswer((_) async => true);

    expect(await useCase('correct'), isTrue);
    verify(() => vault.unlock('correct')).called(1);
  });

  test('returns false when VaultService.unlock fails', () async {
    when(() => vault.unlock(any())).thenAnswer((_) async => false);

    expect(await useCase('wrong'), isFalse);
  });
}
