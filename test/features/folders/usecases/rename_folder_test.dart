import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/rename_folder.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  test('forwards id and new name to FolderRepository.rename', () async {
    final repo = _MockFolderRepository();
    when(() => repo.rename(any(), any())).thenAnswer((_) async {});

    await RenameFolderUseCase(repo)(id: 1, newName: 'Personal');

    verify(() => repo.rename(1, 'Personal')).called(1);
  });
}
