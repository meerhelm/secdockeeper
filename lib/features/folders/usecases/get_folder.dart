import '../folder.dart';
import '../folder_repository.dart';

class GetFolderUseCase {
  GetFolderUseCase(this._repo);

  final FolderRepository _repo;

  Future<Folder?> call(int id) => _repo.getById(id);
}
