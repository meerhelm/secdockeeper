import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document_open_service.dart';
import 'package:secdockeeper/features/vault/usecases/lock_vault.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

class _MockDocumentOpenService extends Mock implements DocumentOpenService {}

void main() {
  test('clears temp before locking the vault', () async {
    final vault = _MockVaultService();
    final opener = _MockDocumentOpenService();
    when(() => opener.deleteAllTemp()).thenAnswer((_) async {});
    when(() => vault.lock()).thenAnswer((_) async {});

    await LockVaultUseCase(vault: vault, opener: opener)();

    verifyInOrder([
      () => opener.deleteAllTemp(),
      () => vault.lock(),
    ]);
  });
}
