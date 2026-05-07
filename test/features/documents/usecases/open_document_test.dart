import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_filex/open_filex.dart';
import 'package:secdockeeper/features/documents/document.dart';
import 'package:secdockeeper/features/documents/document_open_service.dart';
import 'package:secdockeeper/features/documents/usecases/open_document.dart';

class _MockDocumentOpenService extends Mock implements DocumentOpenService {}

class _FakeDocument extends Fake implements Document {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDocument());
  });

  test('forwards document to DocumentOpenService.open', () async {
    final opener = _MockDocumentOpenService();
    when(() => opener.open(any())).thenAnswer(
      (_) async => OpenResult(type: ResultType.done),
    );
    final doc = Document(
      id: 1,
      uuid: 'u',
      originalName: 'n',
      mimeType: null,
      size: 0,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

    await OpenDocumentUseCase(opener)(doc);

    verify(() => opener.open(doc)).called(1);
  });
}
