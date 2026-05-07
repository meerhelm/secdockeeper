import '../tag_repository.dart';

class UnassignTagUseCase {
  UnassignTagUseCase(this._repo);

  final TagRepository _repo;

  Future<void> call({required int documentId, required int tagId}) =>
      _repo.unassign(documentId, tagId);
}
