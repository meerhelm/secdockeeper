import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/crypto/vault_crypto.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/secure_temp.dart';
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
    final uuid = _uuid.v4();
    // Bind the wrapped DEK and the blob to this row's uuid (M-2).
    final aad = rowAad(formatVersion: kCurrentRowFormatVersion, uuid: uuid);
    final dek = await crypto.generateDek();
    final wrapped = await crypto.wrapDek(kek: _vault.wrapKey, dek: dek, aad: aad);
    final sealed = await crypto.encryptBlob(dek: dek, plaintext: bytes, aad: aad);

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
        formatVersion: kCurrentRowFormatVersion,
      );
      return (await _repository.getById(id))!;
    } catch (e, st) {
      log.e('[document_import] metadata insert failed; rolling back blob',
          error: e, stackTrace: st);
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

    final scratch = await SecureTemp.dir(SecureTemp.ocr);
    final file = File(p.join(scratch.path, 'src_${_uuid.v4()}'));
    try {
      await file.writeAsBytes(bytes, flush: true);
      return await _ocr.recognize(file, mimeType: mimeType);
    } finally {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (e, st) {
          log.w('[document_import] ocr scratch cleanup failed',
              error: e, stackTrace: st);
        }
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
