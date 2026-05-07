import 'dart:typed_data';

class Document {
  const Document({
    required this.id,
    required this.uuid,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.createdAt,
    required this.updatedAt,
    this.ocrText,
    this.classificationAuto,
    this.classificationManual,
    this.folderId,
  });

  final int id;
  final String uuid;
  final String originalName;
  final String? mimeType;
  final int size;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ocrText;
  final String? classificationAuto;
  final String? classificationManual;
  final int? folderId;

  String? get classification => classificationManual ?? classificationAuto;

  factory Document.fromRow(Map<String, Object?> row) => Document(
        id: row['id']! as int,
        uuid: row['uuid']! as String,
        originalName: row['original_name']! as String,
        mimeType: row['mime_type'] as String?,
        size: row['size']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
        ocrText: row['ocr_text'] as String?,
        classificationAuto: row['classification_auto'] as String?,
        classificationManual: row['classification_manual'] as String?,
        folderId: row['folder_id'] as int?,
      );
}

class DocumentCryptoMaterial {
  const DocumentCryptoMaterial({
    required this.dekWrapped,
    required this.dekNonce,
    required this.dekMac,
    required this.fileNonce,
    required this.fileMac,
  });

  final Uint8List dekWrapped;
  final Uint8List dekNonce;
  final Uint8List dekMac;
  final Uint8List fileNonce;
  final Uint8List fileMac;
}
