import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/backup/backup_service.dart';
import 'package:secdockeeper/features/backup/usecases/export_backup.dart';
import 'package:secdockeeper/features/documents/document_open_service.dart';

class _MockBackupService extends Mock implements BackupService {}

class _MockDocumentOpenService extends Mock implements DocumentOpenService {}

class _FakeBackupArchive extends Fake implements BackupArchive {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBackupArchive());
  });

  test('clears temp, exports, then shares — in that order', () async {
    final backup = _MockBackupService();
    final opener = _MockDocumentOpenService();
    final archive = BackupArchive(file: File('/tmp/sdk-backup.zip'));
    when(() => opener.deleteAllTemp()).thenAnswer((_) async {});
    when(() => backup.exportVault()).thenAnswer((_) async => archive);
    when(() => backup.shareViaSystem(any())).thenAnswer((_) async {});

    final result = await ExportBackupUseCase(
      backup: backup,
      opener: opener,
    )();

    expect(result, archive);
    verifyInOrder([
      () => opener.deleteAllTemp(),
      () => backup.exportVault(),
      () => backup.shareViaSystem(archive),
    ]);
  });
}
