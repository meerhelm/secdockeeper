import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';
import 'package:secdockeeper/features/tags/usecases/list_all_tags.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  test('forwards to TagRepository.listAll', () async {
    final repo = _MockTagRepository();
    when(() => repo.listAll()).thenAnswer((_) async => []);

    await ListAllTagsUseCase(repo)();

    verify(() => repo.listAll()).called(1);
  });
}
