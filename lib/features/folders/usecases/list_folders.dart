import '../folder.dart';
import '../folder_repository.dart';

class ListFoldersUseCase {
  ListFoldersUseCase(this._repo);

  final FolderRepository _repo;

  Future<List<Folder>> call() => _repo.listAll();
}
