import '../folder.dart';
import '../folder_repository.dart';

class CreateFolderUseCase {
  CreateFolderUseCase(this._repo);

  final FolderRepository _repo;

  Future<Folder> call(String name) => _repo.create(name);
}
