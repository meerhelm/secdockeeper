import '../document_repository.dart';

class WatchDocumentChangesUseCase {
  WatchDocumentChangesUseCase(this._repo);

  final DocumentRepository _repo;

  Stream<void> call() => _repo.changes;
}
