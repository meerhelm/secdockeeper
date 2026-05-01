import 'dart:io';

import '../backup_service.dart';

class RestoreBackupUseCase {
  RestoreBackupUseCase(this._backup);

  final BackupService _backup;

  Future<void> call(File archiveFile) =>
      _backup.restoreFromArchive(archiveFile);
}
