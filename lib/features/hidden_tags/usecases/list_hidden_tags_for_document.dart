import '../hidden_tag_repository.dart';

class ListHiddenTagsForDocumentUseCase {
  ListHiddenTagsForDocumentUseCase(this._repo);

  final HiddenTagRepository _repo;

  Future<List<String>> call(int documentId) =>
      _repo.namesForDocument(documentId);
}
