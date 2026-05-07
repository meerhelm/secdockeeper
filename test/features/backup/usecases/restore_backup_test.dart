import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secdockeeper/features/backup/backup_service.dart';
import 'package:secdockeeper/features/backup/usecases/restore_backup.dart';

class _MockBackupService extends Mock implements BackupService {}

class _FakeFile extends Fake implements File {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFile());
  });

  late _MockBackupService backup;
  late RestoreBackupUseCase useCase;

  setUp(() {
    backup = _MockBackupService();
    useCase = RestoreBackupUseCase(backup);
  });

  test('forwards file to BackupService.restoreFromArchive', () async {
    when(() => backup.restoreFromArchive(any())).thenAnswer((_) async {});
    final file = File('/tmp/some.zip');

    await useCase(file);

    verify(() => backup.restoreFromArchive(file)).called(1);
  });

  test('propagates errors from BackupService', () async {
    when(() => backup.restoreFromArchive(any()))
        .thenThrow(const FormatException('bad archive'));

    expect(() => useCase(_FakeFile()), throwsFormatException);
  });
}
