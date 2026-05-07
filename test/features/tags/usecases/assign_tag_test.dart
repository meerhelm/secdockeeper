import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';
import 'package:secdockeeper/features/tags/usecases/assign_tag.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  test('forwards documentId and tagId to TagRepository.assign', () async {
    final repo = _MockTagRepository();
    when(() => repo.assign(any(), any())).thenAnswer((_) async {});

    await AssignTagUseCase(repo)(documentId: 5, tagId: 12);

    verify(() => repo.assign(5, 12)).called(1);
  });
}
