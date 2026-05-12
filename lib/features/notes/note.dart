import 'dart:typed_data';

class Note {
  const Note({
    required this.id,
    required this.uuid,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
  });

  final int id;
  final String uuid;
  final String title;

  /// Decrypted body. The on-disk representation is AES-GCM-encrypted under a
  /// per-note DEK; the repository hydrates this field on read.
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? folderId;

  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final firstLine = body.trim().split('\n').first.trim();
    if (firstLine.isNotEmpty) return firstLine;
    return 'Untitled note';
  }

  String get preview {
    final source = title.trim().isEmpty ? body : body;
    final compact = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 140) return compact;
    return '${compact.substring(0, 140)}…';
  }
}

class NoteCryptoMaterial {
  const NoteCryptoMaterial({
    required this.dekWrapped,
    required this.dekNonce,
    required this.dekMac,
    required this.bodyCiphertext,
    required this.bodyNonce,
    required this.bodyMac,
  });

  final Uint8List dekWrapped;
  final Uint8List dekNonce;
  final Uint8List dekMac;
  final Uint8List bodyCiphertext;
  final Uint8List bodyNonce;
  final Uint8List bodyMac;
}
