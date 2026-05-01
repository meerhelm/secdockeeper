import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/list_folders.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  test('forwards to FolderRepository.listAll', () async {
    final repo = _MockFolderRepository();
    when(() => repo.listAll()).thenAnswer((_) async => []);

    await ListFoldersUseCase(repo)();

    verify(() => repo.listAll()).called(1);
  });
}
