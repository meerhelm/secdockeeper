import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document.dart';
import 'package:secdockeeper/features/documents/document_repository.dart';
import 'package:secdockeeper/features/documents/usecases/search_documents.dart';
import 'package:secdockeeper/features/hidden_tags/hidden_tag_repository.dart';
import 'package:secdockeeper/features/tags/tag_repository.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _MockTagRepository extends Mock implements TagRepository {}

class _MockHiddenTagRepository extends Mock implements HiddenTagRepository {}

Document _doc(int id) => Document(
      id: id,
      uuid: 'u$id',
      originalName: 'doc$id.txt',
      mimeType: 'text/plain',
      size: 1,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

void main() {
  late _MockDocumentRepository docs;
  late _MockTagRepository tags;
  late _MockHiddenTagRepository hidden;
  late SearchDocumentsUseCase useCase;

  setUp(() {
    docs = _MockDocumentRepository();
    tags = _MockTagRepository();
    hidden = _MockHiddenTagRepository();
    useCase = SearchDocumentsUseCase(
      documents: docs,
      tags: tags,
      hiddenTags: hidden,
    );
  });

  test('returns documents.list directly when query is null/empty', () async {
    when(() => docs.list(
          query: any(named: 'query'),
          tagIds: any(named: 'tagIds'),
          folderId: any(named: 'folderId'),
          onlyUnassignedFolder: any(named: 'onlyUnassignedFolder'),
        )).thenAnswer((_) async => [_doc(1), _doc(2)]);

    final result = await useCase();

    expect(result.map((d) => d.id), [1, 2]);
    verifyNever(() => tags.findDocumentsByQuery(any()));
    verifyNever(() => hidden.findDocumentsByName(any()));
  });

  test('returns the simple FTS list when no tag/hidden matches', () async {
    when(() => docs.list(
          query: 'q',
          tagIds: any(named: 'tagIds'),
          folderId: any(named: 'folderId'),
          onlyUnassignedFolder: any(named: 'onlyUnassignedFolder'),
        )).thenAnswer((_) async => [_doc(1)]);
    when(() => tags.findDocumentsByQuery('q')).thenAnswer((_) async => []);
    when(() => hidden.findDocumentsByName('q')).thenAnswer((_) async => []);

    final result = await useCase(query: 'q');

    expect(result.map((d) => d.id), [1]);
  });

  test('puts tag/hidden matches first, then FTS, deduplicated', () async {
    // FTS layer returns 1 and 2.
    when(() => docs.list(
          query: 'foo',
          tagIds: null,
          folderId: null,
          onlyUnassignedFolder: false,
        )).thenAnswer((_) async => [_doc(1), _doc(2)]);

    // Tag and hidden lookups together yield doc ids 2 and 3.
    when(() => tags.findDocumentsByQuery('foo'))
        .thenAnswer((_) async => [2]);
    when(() => hidden.findDocumentsByName('foo'))
        .thenAnswer((_) async => [3]);

    // The second list call (with hiddenDocIds) returns docs 2 and 3 in any
    // order; the usecase will dedupe.
    when(() => docs.list(
          query: null,
          tagIds: null,
          hiddenDocIds: any(named: 'hiddenDocIds'),
          folderId: null,
          onlyUnassignedFolder: false,
        )).thenAnswer((_) async => [_doc(3), _doc(2)]);

    final result = await useCase(query: 'foo');

    // Tag/hidden matches first, then any remaining FTS results.
    expect(result.map((d) => d.id), [3, 2, 1]);
  });

  test('forwards folder + tag filters to documents.list', () async {
    when(() => docs.list(
          query: null,
          tagIds: [10, 20],
          folderId: 5,
          onlyUnassignedFolder: false,
        )).thenAnswer((_) async => []);

    await useCase(tagIds: [10, 20], folderId: 5);

    verify(() => docs.list(
          query: null,
          tagIds: [10, 20],
          folderId: 5,
          onlyUnassignedFolder: false,
        )).called(1);
  });
}
