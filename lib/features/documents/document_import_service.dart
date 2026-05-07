import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../ocr/auto_classifier.dart';
import '../ocr/ocr_service.dart';
import '../vault/vault_service.dart';
import 'document.dart';
import 'document_repository.dart';

class DocumentImportService {
  DocumentImportService({
    required VaultService vault,
    required DocumentRepository repository,
    required OcrService ocr,
    required AutoClassifier classifier,
  })  : _vault = vault,
        _repository = repository,
        _ocr = ocr,
        _classifier = classifier;

  final VaultService _vault;
  final DocumentRepository _repository;
  final OcrService _ocr;
  final AutoClassifier _classifier;
  static const _uuid = Uuid();

  Future<Document> importBytes({
    required Uint8List bytes,
    required String originalName,
    String? mimeType,
    String? ocrTextOverride,
    String? classificationAutoOverride,
    bool runOcr = true,
  }) async {
    final resolvedMime = mimeType ?? lookupMimeType(originalName);

    String? ocrText = ocrTextOverride;
    if (ocrText == null && runOcr) {
      ocrText = await _maybeRunOcr(bytes: bytes, mimeType: resolvedMime);
    }
    final classificationAuto = classificationAutoOverride ??
        _classifier.classify(originalName: originalName, ocrText: ocrText);

    final crypto = _vault.crypto;
    final dek = await crypto.generateDek();
    final wrapped = await crypto.wrapDek(kek: _vault.kek, dek: dek);
    final sealed = await crypto.encryptBlob(dek: dek, plaintext: bytes);

    final uuid = _uuid.v4();
    await _vault.blobStore.write(uuid, sealed.ciphertext);

    try {
      final id = await _repository.create(
        uuid: uuid,
        originalName: originalName,
        mimeType: resolvedMime,
        size: bytes.length,
        dekWrapped: wrapped.ciphertext,
        dekNonce: wrapped.nonce,
        dekMac: wrapped.mac,
        fileNonce: sealed.nonce,
        fileMac: sealed.mac,
        ocrText: ocrText,
        classificationAuto: classificationAuto,
      );
      return (await _repository.getById(id))!;
    } catch (e) {
      await _vault.blobStore.delete(uuid);
      rethrow;
    }
  }

  Future<String?> _maybeRunOcr({
    required Uint8List bytes,
    required String? mimeType,
  }) async {
    if (!OcrService.isSupported) return null;
    if (mimeType == null || !mimeType.startsWith('image/')) return null;

    final tmpDir = await getTemporaryDirectory();
    final scratch = Directory(p.join(tmpDir.path, 'ocr_scratch'));
    if (!scratch.existsSync()) scratch.createSync(recursive: true);
    final file = File(p.join(scratch.path, 'src_${_uuid.v4()}'));
    try {
      await file.writeAsBytes(bytes, flush: true);
      return await _ocr.recognize(file, mimeType: mimeType);
    } finally {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<Document> importFile(File file) async {
    final bytes = await file.readAsBytes();
    return importBytes(
      bytes: bytes,
      originalName: p.basename(file.path),
      mimeType: lookupMimeType(file.path),
    );
  }
}
