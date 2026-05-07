import '../../documents/document_open_service.dart';
import '../backup_service.dart';

class ExportBackupUseCase {
  ExportBackupUseCase({
    required BackupService backup,
    required DocumentOpenService opener,
  })  : _backup = backup,
        _opener = opener;

  final BackupService _backup;
  final DocumentOpenService _opener;

  Future<BackupArchive> call() async {
    await _opener.deleteAllTemp();
    final archive = await _backup.exportVault();
    await _backup.shareViaSystem(archive);
    return archive;
  }
}
