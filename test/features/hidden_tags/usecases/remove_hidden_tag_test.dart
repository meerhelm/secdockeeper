import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/hidden_tags/hidden_tag_repository.dart';
import 'package:secdockeeper/features/hidden_tags/usecases/remove_hidden_tag.dart';

class _MockHiddenTagRepository extends Mock implements HiddenTagRepository {}

void main() {
  test('forwards documentId and name to HiddenTagRepository.removeByName',
      () async {
    final repo = _MockHiddenTagRepository();
    when(() => repo.removeByName(any(), any())).thenAnswer((_) async {});

    await RemoveHiddenTagUseCase(repo)(documentId: 4, name: 'project-x');

    verify(() => repo.removeByName(4, 'project-x')).called(1);
  });
}
