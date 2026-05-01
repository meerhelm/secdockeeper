import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';
import 'package:secdockeeper/features/tags/usecases/watch_tag_changes.dart';

class _MockTagRepository extends Mock implements TagRepository {}

void main() {
  test('exposes the repository changes stream', () {
    final repo = _MockTagRepository();
    final stream = const Stream<void>.empty();
    when(() => repo.changes).thenAnswer((_) => stream);

    expect(WatchTagChangesUseCase(repo)(), same(stream));
  });
}
