import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/paths.dart';
import '../vault/vault_service.dart';

class BackupArchive {
  BackupArchive({required this.file});
  final File file;
}

class BackupService {
  BackupService({required VaultService vault, required VaultPaths paths})
      : _vault = vault,
        _paths = paths;

  final VaultService _vault;
  final VaultPaths _paths;
  static const _uuid = Uuid();
  static const _formatVersion = 1;
  static const _manifestName = 'sdk_backup_manifest.txt';

  Future<BackupArchive> exportVault() async {
    if (_vault.state == VaultState.unlocked) {
      await _vault.lock();
    }

    final tmp = await getTemporaryDirectory();
    final outDir = Directory(p.join(tmp.path, 'sdk_backup', _uuid.v4()));
    outDir.createSync(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final outFile = File(p.join(outDir.path, 'secdockeeper-backup-$stamp.zip'));

    final encoder = ZipFileEncoder();
    encoder.create(outFile.path);
    try {
      encoder.addArchiveFile(ArchiveFile.string(
        _manifestName,
        'secdockeeper-backup\nversion=$_formatVersion\ncreated=${DateTime.now().toIso8601String()}\n',
      ));

      final root = _paths.root;
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: root.path);
          encoder.addFile(entity, rel);
        }
      }
    } finally {
      encoder.close();
    }
    return BackupArchive(file: outFile);
  }

  Future<void> shareViaSystem(BackupArchive backup) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backup.file.path)],
        text: 'Encrypted SecDockKeeper backup. The master password is required to unlock.',
      ),
    );
  }

  Future<void> restoreFromArchive(File archiveFile) async {
    if (_vault.state != VaultState.uninitialized) {
      throw StateError('Restore is only allowed when no vault exists yet.');
    }

    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestEntry = archive.files.firstWhere(
      (f) => f.name == _manifestName,
      orElse: () => throw const FormatException('Not a SecDockKeeper backup archive'),
    );
    _validateManifest(manifestEntry);

    final root = _paths.root;
    if (root.existsSync()) {
      _emptyDirectory(root);
    } else {
      root.createSync(recursive: true);
    }

    for (final entry in archive.files) {
      if (entry.name == _manifestName) continue;
      if (!entry.isFile) continue;
      final outPath = p.join(root.path, entry.name);
      _assertWithinRoot(root.path, outPath);
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>, flush: true);
    }

    final blobs = Directory(p.join(root.path, 'blobs'));
    if (!blobs.existsSync()) {
      blobs.createSync(recursive: true);
    }

    _vault.notifyExternalChange();
  }

  void _validateManifest(ArchiveFile entry) {
    final text = String.fromCharCodes(entry.content as List<int>);
    if (!text.contains('secdockeeper-backup')) {
      throw const FormatException('Invalid backup manifest');
    }
    final versionMatch = RegExp(r'version=(\d+)').firstMatch(text);
    final version = versionMatch == null ? 0 : int.tryParse(versionMatch.group(1)!) ?? 0;
    if (version != _formatVersion) {
      throw FormatException('Unsupported backup version: $version');
    }
  }

  void _emptyDirectory(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      try {
        entity.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  void _assertWithinRoot(String root, String target) {
    final normalized = p.normalize(target);
    if (!p.isWithin(root, normalized) && p.normalize(root) != normalized) {
      throw FormatException('Archive entry escapes vault directory: $target');
    }
  }
}

