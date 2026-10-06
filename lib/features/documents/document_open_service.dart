import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/crypto/aead.dart';
import '../../core/crypto/vault_crypto.dart';
import '../../core/storage/temp_files.dart';
import '../vault/vault_service.dart';
import 'document.dart';
import 'document_repository.dart';

class DocumentOpenService {
  DocumentOpenService({
    required VaultService vault,
    required DocumentRepository repository,
  })  : _vault = vault,
        _repository = repository;

  final VaultService _vault;
  final DocumentRepository _repository;

  Future<Uint8List> decryptBytes(Document document) async {
    final material = await _repository.getCryptoFor(document.id);
    if (material == null) {
      throw StateError('Crypto material missing for document ${document.id}');
    }
    final dek = await _vault.crypto.unwrapDek(
      kek: _vault.kek,
      wrapped: WrappedDek(
        nonce: material.dekNonce,
        ciphertext: material.dekWrapped,
        mac: material.dekMac,
      ),
    );
    final ciphertext = await _vault.blobStore.read(document.uuid);
    return _vault.crypto.decryptBlob(
      dek: dek,
      sealed: SealedBytes(
        nonce: material.fileNonce,
        ciphertext: ciphertext,
        mac: material.fileMac,
      ),
    );
  }

  Future<File> decryptToTempFile(Document document) async {
    final bytes = await decryptBytes(document);
    final viewDir = await TempFiles.dir(TempFiles.viewDir);
    // One folder per document keeps the original name for the viewer without
    // letting two documents with the same name overwrite each other. Both
    // segments are sanitized: the name can come from a shared package.
    final docDir = Directory(p.join(viewDir.path, sanitizeFileName(document.uuid)));
    if (!docDir.existsSync()) docDir.createSync(recursive: true);
    final outFile = File(p.join(docDir.path, sanitizeFileName(document.originalName)));
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  Future<OpenResult> open(Document document) async {
    final file = await decryptToTempFile(document);
    return OpenFilex.open(file.path, type: document.mimeType);
  }

  Future<void> deleteAllTemp() => TempFiles.wipe();
}
