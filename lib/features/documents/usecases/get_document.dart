import '../document.dart';
import '../document_repository.dart';

class GetDocumentUseCase {
  GetDocumentUseCase(this._repo);

  final DocumentRepository _repo;

  Future<Document?> call(int id) => _repo.getById(id);
}
