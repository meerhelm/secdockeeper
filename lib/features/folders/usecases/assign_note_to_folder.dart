import '../folder_repository.dart';

class AssignNoteToFolderUseCase {
  AssignNoteToFolderUseCase(this._repo);

  final FolderRepository _repo;

  Future<void> call({required int noteId, int? folderId}) =>
      _repo.assignNote(noteId, folderId);
}
