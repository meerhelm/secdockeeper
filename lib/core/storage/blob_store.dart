import 'dart:io';
import 'dart:typed_data';

import 'paths.dart';

class BlobStore {
  BlobStore(this._paths);

  final VaultPaths _paths;

  Future<void> write(String uuid, Uint8List ciphertext) async {
    final file = _paths.blobFile(uuid);
    await file.writeAsBytes(ciphertext, flush: true);
  }

  Future<Uint8List> read(String uuid) async {
    final file = _paths.blobFile(uuid);
    final bytes = await file.readAsBytes();
    return Uint8List.fromList(bytes);
  }

  Future<void> delete(String uuid) async {
    final file = _paths.blobFile(uuid);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  bool exists(String uuid) => _paths.blobFile(uuid).existsSync();

  File fileFor(String uuid) => _paths.blobFile(uuid);
}
