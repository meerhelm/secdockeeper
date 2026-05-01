import '../document_repository.dart';

class RenameDocumentUseCase {
  RenameDocumentUseCase(this._repo);

  final DocumentRepository _repo;

  Future<void> call({required int id, required String newName}) =>
      _repo.rename(id, newName);
}
