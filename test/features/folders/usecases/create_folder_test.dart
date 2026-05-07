import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/create_folder.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  test('forwards name to FolderRepository.create', () async {
    final repo = _MockFolderRepository();
    when(() => repo.create(any())).thenAnswer(
      (_) async => Folder(id: 1, name: 'Work', createdAt: DateTime(2025)),
    );

    await CreateFolderUseCase(repo)('Work');

    verify(() => repo.create('Work')).called(1);
  });
}
