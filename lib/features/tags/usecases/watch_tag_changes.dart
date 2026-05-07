import '../tag_repository.dart';

class WatchTagChangesUseCase {
  WatchTagChangesUseCase(this._repo);

  final TagRepository _repo;

  Stream<void> call() => _repo.changes;
}
