import '../note_repository.dart';

class DeleteNoteUseCase {
  DeleteNoteUseCase(this._repo);

  final NoteRepository _repo;

  Future<void> call(int id) => _repo.deleteById(id);
}
