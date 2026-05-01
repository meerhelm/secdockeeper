import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/folders/folder_repository.dart';
import 'package:secdockeeper/features/folders/usecases/assign_document_to_folder.dart';

class _MockFolderRepository extends Mock implements FolderRepository {}

void main() {
  late _MockFolderRepository repo;
  late AssignDocumentToFolderUseCase useCase;

  setUp(() {
    repo = _MockFolderRepository();
    useCase = AssignDocumentToFolderUseCase(repo);
  });

  test('forwards documentId and folderId to repository', () async {
    when(() => repo.assignDocument(any(), any())).thenAnswer((_) async {});

    await useCase(documentId: 1, folderId: 5);

    verify(() => repo.assignDocument(1, 5)).called(1);
  });

  test('passes null folderId for unassigning', () async {
    when(() => repo.assignDocument(any(), any())).thenAnswer((_) async {});

    await useCase(documentId: 2, folderId: null);

    verify(() => repo.assignDocument(2, null)).called(1);
  });
}
