import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/hidden_tags/hidden_tag_repository.dart';
import 'package:secdockeeper/features/hidden_tags/usecases/list_hidden_tags_for_document.dart';

class _MockHiddenTagRepository extends Mock implements HiddenTagRepository {}

void main() {
  test('forwards documentId to HiddenTagRepository.namesForDocument', () async {
    final repo = _MockHiddenTagRepository();
    when(() => repo.namesForDocument(any())).thenAnswer((_) async => []);

    await ListHiddenTagsForDocumentUseCase(repo)(8);

    verify(() => repo.namesForDocument(8)).called(1);
  });
}
