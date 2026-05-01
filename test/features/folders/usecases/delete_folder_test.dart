import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/delete_folder.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  test('forwards id to FolderRepository.delete', () async {
    final repo = _MockFolderRepository();
    when(() => repo.delete(any())).thenAnswer((_) async {});

    await DeleteFolderUseCase(repo)(7);

    verify(() => repo.delete(7)).called(1);
  });
}
