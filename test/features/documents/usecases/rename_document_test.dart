import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document_repository.dart';
import 'package:secdockeeper/features/documents/usecases/rename_document.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  test('forwards id and name to DocumentRepository.rename', () async {
    final repo = _MockDocumentRepository();
    when(() => repo.rename(any(), any())).thenAnswer((_) async {});

    await RenameDocumentUseCase(repo)(id: 3, newName: 'fresh');

    verify(() => repo.rename(3, 'fresh')).called(1);
  });
}
