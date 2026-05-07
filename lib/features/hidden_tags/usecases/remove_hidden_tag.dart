import '../hidden_tag_repository.dart';

class RemoveHiddenTagUseCase {
  RemoveHiddenTagUseCase(this._repo);

  final HiddenTagRepository _repo;

  Future<void> call({required int documentId, required String name}) =>
      _repo.removeByName(documentId, name);
}
