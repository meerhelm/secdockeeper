import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document_repository.dart';
import 'package:secdockeeper/features/documents/usecases/watch_document_changes.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  test('exposes the repository changes stream', () {
    final repo = _MockDocumentRepository();
    final controller = Stream<void>.empty();
    when(() => repo.changes).thenAnswer((_) => controller);

    final stream = WatchDocumentChangesUseCase(repo)();

    expect(stream, same(controller));
  });
}
