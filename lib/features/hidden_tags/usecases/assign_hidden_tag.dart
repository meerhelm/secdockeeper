import '../hidden_tag_repository.dart';

class AssignHiddenTagUseCase {
  AssignHiddenTagUseCase(this._repo);

  final HiddenTagRepository _repo;

  Future<void> call({required int documentId, required String name}) =>
      _repo.assignByName(documentId, name);
}
