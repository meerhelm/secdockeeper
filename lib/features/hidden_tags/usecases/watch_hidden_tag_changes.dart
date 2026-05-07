import '../hidden_tag_repository.dart';

class WatchHiddenTagChangesUseCase {
  WatchHiddenTagChangesUseCase(this._repo);

  final HiddenTagRepository _repo;

  Stream<void> call() => _repo.changes;
}
