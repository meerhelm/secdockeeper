import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/watch_folder_changes.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  test('exposes the repository changes stream', () {
    final repo = _MockFolderRepository();
    final stream = const Stream<void>.empty();
    when(() => repo.changes).thenAnswer((_) => stream);

    expect(WatchFolderChangesUseCase(repo)(), same(stream));
  });
}
