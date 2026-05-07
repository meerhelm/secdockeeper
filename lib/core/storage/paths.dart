import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultPaths {
  VaultPaths._(this.root);

  final Directory root;

  static Future<VaultPaths> resolve() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'secdockeeper'));
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    final blobs = Directory(p.join(root.path, 'blobs'));
    if (!blobs.existsSync()) {
      blobs.createSync(recursive: true);
    }
    return VaultPaths._(root);
  }

  String get databasePath => p.join(root.path, 'vault.db');

  Directory get blobsDir => Directory(p.join(root.path, 'blobs'));

  File blobFile(String uuid) => File(p.join(blobsDir.path, '$uuid.enc'));
}
