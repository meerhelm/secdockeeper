import '../folder_repository.dart';

class WatchFolderChangesUseCase {
  WatchFolderChangesUseCase(this._repo);

  final FolderRepository _repo;

  Stream<void> call() => _repo.changes;
}
