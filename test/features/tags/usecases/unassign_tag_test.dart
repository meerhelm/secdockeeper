import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';
import 'package:secdockeeper/features/tags/usecases/unassign_tag.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  test('forwards documentId/tagId to TagRepository.unassign', () async {
    final repo = _MockTagRepository();
    when(() => repo.unassign(any(), any())).thenAnswer((_) async {});

    await UnassignTagUseCase(repo)(documentId: 4, tagId: 9);

    verify(() => repo.unassign(4, 9)).called(1);
  });
}
