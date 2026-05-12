import '../note.dart';
import '../note_repository.dart';

class CreateNoteUseCase {
  CreateNoteUseCase(this._repo);

  final NoteRepository _repo;

  Future<Note> call({String title = '', String body = ''}) =>
      _repo.create(title: title, body: body);
}
