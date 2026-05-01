import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/hidden_tags/hidden_tag_repository.dart';
import 'package:secdockeeper/features/hidden_tags/usecases/watch_hidden_tag_changes.dart';

class _MockHiddenTagRepository extends Mock implements HiddenTagRepository {}

void main() {
  test('exposes the repository changes stream', () {
    final repo = _MockHiddenTagRepository();
    final stream = const Stream<void>.empty();
    when(() => repo.changes).thenAnswer((_) => stream);

    expect(WatchHiddenTagChangesUseCase(repo)(), same(stream));
  });
}
