import '../note.dart';
import '../note_repository.dart';

class GetNoteUseCase {
  GetNoteUseCase(this._repo);

  final NoteRepository _repo;

  Future<Note?> call(int id) => _repo.getById(id);
}
