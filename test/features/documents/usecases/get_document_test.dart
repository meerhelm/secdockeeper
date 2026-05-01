import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document_repository.dart';
import 'package:secdockeeper/features/documents/usecases/get_document.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  test('forwards id to DocumentRepository.getById', () async {
    final repo = _MockDocumentRepository();
    when(() => repo.getById(any())).thenAnswer((_) async => null);

    await GetDocumentUseCase(repo)(42);

    verify(() => repo.getById(42)).called(1);
  });
}
