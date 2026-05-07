import '../tag.dart';
import '../tag_repository.dart';

class ListTagsForDocumentUseCase {
  ListTagsForDocumentUseCase(this._repo);

  final TagRepository _repo;

  Future<List<Tag>> call(int documentId) => _repo.forDocument(documentId);
}
