import '../folder_repository.dart';

class DeleteFolderUseCase {
  DeleteFolderUseCase(this._repo);

  final FolderRepository _repo;

  Future<void> call(int id) => _repo.delete(id);
}
