import '../tag.dart';
import '../tag_repository.dart';

class UpsertTagUseCase {
  UpsertTagUseCase(this._repo);

  final TagRepository _repo;

  Future<Tag> call(String name) => _repo.upsert(name);
}
