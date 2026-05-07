import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';
import 'package:secdockeeper/features/tags/usecases/list_tags_for_document.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  test('forwards documentId to TagRepository.forDocument', () async {
    final repo = _MockTagRepository();
    when(() => repo.forDocument(any())).thenAnswer((_) async => []);

    await ListTagsForDocumentUseCase(repo)(99);

    verify(() => repo.forDocument(99)).called(1);
  });
}
