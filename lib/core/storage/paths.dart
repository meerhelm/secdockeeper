import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultPaths {
  VaultPaths._(this.root);

  /// Build paths over an explicit root directory. Used by the multi-vault
  /// manager (per-vault directories) and by tests, which can point at a temp
  /// dir without going through `path_provider`.
  factory VaultPaths.forRoot(Directory root) {
    if (!root.existsSync()) root.createSync(recursive: true);
    final blobs = Directory(p.join(root.path, 'blobs'));
    if (!blobs.existsSync()) blobs.createSync(recursive: true);
    return VaultPaths._(root);
  }

  final Directory root;

  static const appDirName = 'secdockeeper';
  static const vaultsDirName = 'vaults';

  /// `<applicationSupportDirectory>/secdockeeper/` — the app root that holds the
  /// vault registry and (under [vaultsDirName]) the per-vault directories. Also
  /// the legacy single-vault root.
  static Future<Directory> appRoot() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, appDirName));
    if (!root.existsSync()) root.createSync(recursive: true);
    return root;
  }

  /// Legacy single-vault layout: vault files directly under `secdockeeper/`.
  /// Retained so an existing install can be migrated into a per-vault dir.
  static Future<VaultPaths> resolve() async {
    final root = await appRoot();
    return VaultPaths.forRoot(root);
  }

  /// Per-vault directory `secdockeeper/vaults/<vaultId>/`.
  static Future<VaultPaths> forVault(String vaultId) async {
    final base = await appRoot();
    final root = Directory(p.join(base.path, vaultsDirName, vaultId));
    return VaultPaths.forRoot(root);
  }

  /// Root for the single optional **hidden** vault. Deliberately a *sibling* of
  /// the primary `secdockeeper/` root (not inside it), so the primary vault's
  /// backup/export and `destroy()` never touch or reveal it. Note: this hides
  /// the hidden vault from the app's own UI/registry and from primary backups,
  /// but it is not forensic-grade deniability — the directory still exists on
  /// disk for anyone inspecting the filesystem.
  static Future<VaultPaths> forHidden() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, '.sdk_sys'));
    return VaultPaths.forRoot(root);
  }

  String get databasePath => p.join(root.path, 'vault.db');

  Directory get blobsDir => Directory(p.join(root.path, 'blobs'));

  File blobFile(String uuid) => File(p.join(blobsDir.path, '$uuid.enc'));
}
