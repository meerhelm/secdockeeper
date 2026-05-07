import 'package:flutter/widgets.dart';

import '../core/storage/paths.dart';
import '../features/backup/backup_service.dart';
import '../features/documents/document_import_service.dart';
import '../features/documents/document_open_service.dart';
import '../features/documents/document_repository.dart';
import '../features/folders/folder_repository.dart';
import '../features/hidden_tags/hidden_tag_repository.dart';
import '../features/ocr/auto_classifier.dart';
import '../features/ocr/ocr_service.dart';
import '../features/scanner/document_scanner_service.dart';
import '../features/security/auto_lock_controller.dart';
import '../features/security/biometric_service.dart';
import '../features/security/lock_settings.dart';
import '../features/sharing/share_service.dart';
import '../features/tags/tag_repository.dart';
import '../features/vault/vault_service.dart';

class AppServices {
  AppServices({
    required this.vault,
    required this.paths,
    required this.lockSettings,
  });

  final VaultService vault;
  final VaultPaths paths;
  final LockSettings lockSettings;

  late final DocumentRepository documents = DocumentRepository(vault);
  late final TagRepository tags = TagRepository(vault);
  late final HiddenTagRepository hiddenTags = HiddenTagRepository(vault);
  late final FolderRepository folders = FolderRepository(vault);
  late final OcrService ocr = OcrService();
  late final AutoClassifier classifier = AutoClassifier();
  late final DocumentImportService importer = DocumentImportService(
    vault: vault,
    repository: documents,
    ocr: ocr,
    classifier: classifier,
  );
  late final DocumentOpenService opener =
      DocumentOpenService(vault: vault, repository: documents);
  late final DocumentScannerService scanner = DocumentScannerService(ocr: ocr);
  late final ShareService share = ShareService(opener: opener, importer: importer);
  late final BackupService backup = BackupService(vault: vault, paths: paths);
  late final BiometricService biometrics = BiometricService();
  late final AutoLockController autoLock =
      AutoLockController(vault: vault, settings: lockSettings);
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
