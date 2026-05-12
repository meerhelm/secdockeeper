import '../note_repository.dart';

class WatchNoteChangesUseCase {
  WatchNoteChangesUseCase(this._repo);

  final NoteRepository _repo;

  Stream<void> call() => _repo.changes;
}
