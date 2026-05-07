import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document_open_service.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';
import 'package:secdockeeper/features/vault/usecases/destroy_vault.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

class _MockDocumentOpenService extends Mock implements DocumentOpenService {}

class _MockLockSettings extends Mock implements LockSettings {}

void main() {
  test('wipes plaintexts, biometric secret, then vault — in that order', () async {
    final vault = _MockVaultService();
    final opener = _MockDocumentOpenService();
    final lockSettings = _MockLockSettings();
    when(() => opener.deleteAllTemp()).thenAnswer((_) async {});
    when(() => lockSettings.clearAll()).thenAnswer((_) async {});
    when(() => vault.destroy()).thenAnswer((_) async {});

    await DestroyVaultUseCase(
      vault: vault,
      opener: opener,
      lockSettings: lockSettings,
    )();

    verifyInOrder([
      () => opener.deleteAllTemp(),
      () => lockSettings.clearAll(),
      () => vault.destroy(),
    ]);
  });
}
