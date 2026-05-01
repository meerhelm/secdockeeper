import '../../hidden_tags/hidden_tag_repository.dart';
import '../../tags/tag_repository.dart';
import '../document.dart';
import '../document_repository.dart';

/// Merges three document sources when a free-text query is present:
/// 1. FTS / metadata match via [DocumentRepository.list]
/// 2. Visible tag name match via [TagRepository.findDocumentsByQuery]
/// 3. Hidden tag name HMAC match via [HiddenTagRepository.findDocumentsByName]
///
/// Results from (2) and (3) are surfaced first so a user typing a hidden tag
/// name reliably sees those matches at the top.
class SearchDocumentsUseCase {
  SearchDocumentsUseCase({
    required DocumentRepository documents,
    required TagRepository tags,
    required HiddenTagRepository hiddenTags,
  })  : _documents = documents,
        _tags = tags,
        _hiddenTags = hiddenTags;

  final DocumentRepository _documents;
  final TagRepository _tags;
  final HiddenTagRepository _hiddenTags;

  Future<List<Document>> call({
    String? query,
    List<int>? tagIds,
    int? folderId,
    bool onlyUnassignedFolder = false,
  }) async {
    final hasQuery = query != null && query.trim().isNotEmpty;
    final normal = await _documents.list(
      query: hasQuery ? query : null,
      tagIds: tagIds,
      folderId: folderId,
      onlyUnassignedFolder: onlyUnassignedFolder,
    );
    if (!hasQuery) return normal;

    final results = await Future.wait([
      _tags.findDocumentsByQuery(query),
      _hiddenTags.findDocumentsByName(query),
    ]);
    final byTagDocIds = <int>{...results[0], ...results[1]};
    if (byTagDocIds.isEmpty) return normal;

    final byTags = await _documents.list(
      tagIds: tagIds,
      hiddenDocIds: byTagDocIds.toList(),
      folderId: folderId,
      onlyUnassignedFolder: onlyUnassignedFolder,
    );

    final seen = <int>{};
    final merged = <Document>[];
    for (final d in byTags) {
      if (seen.add(d.id)) merged.add(d);
    }
    for (final d in normal) {
      if (seen.add(d.id)) merged.add(d);
    }
    return merged;
  }
}
