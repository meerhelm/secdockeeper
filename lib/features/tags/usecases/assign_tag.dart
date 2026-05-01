import '../tag_repository.dart';

class AssignTagUseCase {
  AssignTagUseCase(this._repo);

  final TagRepository _repo;

  Future<void> call({required int documentId, required int tagId}) =>
      _repo.assign(documentId, tagId);
}
