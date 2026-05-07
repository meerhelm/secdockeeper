import '../folder_repository.dart';

class RenameFolderUseCase {
  RenameFolderUseCase(this._repo);

  final FolderRepository _repo;

  Future<void> call({required int id, required String newName}) =>
      _repo.rename(id, newName);
}
