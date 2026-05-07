import '../../vault/vault_service.dart';
import '../document.dart';
import '../document_repository.dart';

class DeleteDocumentUseCase {
  DeleteDocumentUseCase({
    required VaultService vault,
    required DocumentRepository repository,
  })  : _vault = vault,
        _repository = repository;

  final VaultService _vault;
  final DocumentRepository _repository;

  Future<void> call(Document document) async {
    await _vault.blobStore.delete(document.uuid);
    await _repository.deleteById(document.id);
  }
}
