import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document.dart';
import 'package:secdockeeper/features/sharing/share_service.dart';
import 'package:secdockeeper/features/sharing/usecases/share_document.dart';

class _MockShareService extends Mock implements ShareService {}

class _FakeDocument extends Fake implements Document {}

class _FakeShareExport extends Fake implements ShareExport {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDocument());
    registerFallbackValue(_FakeShareExport());
  });

  test('exports document then forwards to share sheet', () async {
    final share = _MockShareService();
    final export = ShareExport(
      blobFile: File('/tmp/x.sdkblob'),
      keyFile: File('/tmp/x.sdkkey.json'),
    );
    when(() => share.exportDocument(any())).thenAnswer((_) async => export);
    when(() => share.shareViaSystem(any())).thenAnswer((_) async {});
    final doc = Document(
      id: 1,
      uuid: 'u',
      originalName: 'n',
      mimeType: null,
      size: 0,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

    await ShareDocumentUseCase(share)(doc);

    verifyInOrder([
      () => share.exportDocument(doc),
      () => share.shareViaSystem(export),
    ]);
  });
}
