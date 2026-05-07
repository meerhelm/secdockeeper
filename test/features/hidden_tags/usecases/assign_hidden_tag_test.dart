import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/hidden_tags/hidden_tag_repository.dart';
import 'package:secdockeeper/features/hidden_tags/usecases/assign_hidden_tag.dart';

class _MockHiddenTagRepository extends Mock implements HiddenTagRepository {}

void main() {
  test('forwards documentId and name to HiddenTagRepository.assignByName',
      () async {
    final repo = _MockHiddenTagRepository();
    when(() => repo.assignByName(any(), any())).thenAnswer((_) async {});

    await AssignHiddenTagUseCase(repo)(
      documentId: 4,
      name: 'project-x',
    );

    verify(() => repo.assignByName(4, 'project-x')).called(1);
  });
}
