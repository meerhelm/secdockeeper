import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/documents/document.dart';
import 'package:secdockeeper/features/sharing/share_service.dart';
import 'package:secdockeeper/features/sharing/usecases/import_shared_package.dart';

class _MockShareService extends Mock implements ShareService {}

class _FakeFile extends Fake implements File {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
  });

  test('forwards files to ShareService.importPackage', () async {
    final share = _MockShareService();
    final blob = File('/tmp/x.sdkblob');
    final key = File('/tmp/x.sdkkey.json');
    final doc = Document(
      id: 1,
      uuid: 'u',
      originalName: 'n',
      mimeType: null,
      size: 0,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
    when(() => share.importPackage(
          blobFile: any(named: 'blobFile'),
          keyFile: any(named: 'keyFile'),
        )).thenAnswer((_) async => doc);

    await ImportSharedPackageUseCase(share)(blobFile: blob, keyFile: key);

    verify(() => share.importPackage(blobFile: blob, keyFile: key)).called(1);
  });
}
