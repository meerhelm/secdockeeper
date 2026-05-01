import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/core/storage/blob_store.dart';
import 'package:secdockeeper/features/documents/document.dart';
import 'package:secdockeeper/features/documents/document_repository.dart';
import 'package:secdockeeper/features/documents/usecases/delete_document.dart';
import 'package:secdockeeper/features/vault/vault_service.dart';

class _MockVaultService extends Mock implements VaultService {}

class _MockBlobStore extends Mock implements BlobStore {}

class _MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late _MockVaultService vault;
  late _MockBlobStore blobStore;
  late _MockDocumentRepository repo;
  late DeleteDocumentUseCase useCase;

  setUp(() {
    vault = _MockVaultService();
    blobStore = _MockBlobStore();
    repo = _MockDocumentRepository();
    when(() => vault.blobStore).thenReturn(blobStore);
    useCase = DeleteDocumentUseCase(vault: vault, repository: repo);
  });

  final doc = Document(
    id: 7,
    uuid: 'abc',
    originalName: 'x',
    mimeType: null,
    size: 0,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );

  test('deletes blob first, then DB row, in order', () async {
    when(() => blobStore.delete(any())).thenAnswer((_) async {});
    when(() => repo.deleteById(any())).thenAnswer((_) async {});

    await useCase(doc);

    verifyInOrder([
      () => blobStore.delete('abc'),
      () => repo.deleteById(7),
    ]);
  });

  test('propagates blob delete errors and skips DB delete', () async {
    when(() => blobStore.delete(any())).thenThrow(StateError('blob gone'));

    await expectLater(() => useCase(doc), throwsStateError);
    verifyNever(() => repo.deleteById(any()));
  });
}
