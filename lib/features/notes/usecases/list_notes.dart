import '../note.dart';
import '../note_repository.dart';

class ListNotesUseCase {
  ListNotesUseCase(this._repo);

  final NoteRepository _repo;

  Future<List<Note>> call({
    String? query,
    int? folderId,
    bool onlyUnassignedFolder = false,
  }) =>
      _repo.list(
        query: query,
        folderId: folderId,
        onlyUnassignedFolder: onlyUnassignedFolder,
      );
}
