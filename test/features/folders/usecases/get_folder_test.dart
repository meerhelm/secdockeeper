import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/get_folder.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  test('forwards id to FolderRepository.getById', () async {
    final repo = _MockFolderRepository();
    when(() => repo.getById(any())).thenAnswer((_) async => null);

    await GetFolderUseCase(repo)(11);

    verify(() => repo.getById(11)).called(1);
  });
}
