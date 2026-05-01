import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/vault/usecases/initialize_vault.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

void main() {
  late _MockVaultService vault;
  late InitializeVaultUseCase useCase;

  setUp(() {
    vault = _MockVaultService();
    useCase = InitializeVaultUseCase(vault);
  });

  test('forwards password to VaultService.initialize', () async {
    when(() => vault.initialize(any())).thenAnswer((_) async {});

    await useCase('hunter2hunter2');

    verify(() => vault.initialize('hunter2hunter2')).called(1);
  });

  test('propagates errors from VaultService.initialize', () async {
    when(() => vault.initialize(any()))
        .thenThrow(StateError('Vault already initialized'));

    expect(() => useCase('p'), throwsStateError);
  });
}
