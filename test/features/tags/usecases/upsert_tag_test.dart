import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/tags/tag.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';
import 'package:secdockeeper/features/tags/usecases/upsert_tag.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  test('forwards name to TagRepository.upsert', () async {
    final repo = _MockTagRepository();
    when(() => repo.upsert(any())).thenAnswer(
      (_) async => Tag(id: 1, name: 'urgent', createdAt: DateTime(2025)),
    );

    final tag = await UpsertTagUseCase(repo)('urgent');

    expect(tag.name, 'urgent');
    verify(() => repo.upsert('urgent')).called(1);
  });
}
