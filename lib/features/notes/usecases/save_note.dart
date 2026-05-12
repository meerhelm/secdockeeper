import '../note_repository.dart';

class SaveNoteUseCase {
  SaveNoteUseCase(this._repo);

  final NoteRepository _repo;

  Future<void> call({
    required int id,
    required String title,
    required String body,
  }) =>
      _repo.update(id: id, title: title, body: body);
}
