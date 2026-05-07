import '../folder_repository.dart';

class AssignDocumentToFolderUseCase {
  AssignDocumentToFolderUseCase(this._repo);

  final FolderRepository _repo;

  Future<void> call({required int documentId, int? folderId}) =>
      _repo.assignDocument(documentId, folderId);
}
