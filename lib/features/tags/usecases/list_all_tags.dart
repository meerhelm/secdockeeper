import '../tag.dart';
import '../tag_repository.dart';

class ListAllTagsUseCase {
  ListAllTagsUseCase(this._repo);

  final TagRepository _repo;

  Future<List<Tag>> call() => _repo.listAll();
}
