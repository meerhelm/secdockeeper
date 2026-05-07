import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/aead.dart';
import '../documents/document.dart';
import '../documents/document_import_service.dart';
import '../documents/document_open_service.dart';

class ShareExport {
  ShareExport({required this.blobFile, required this.keyFile});
  final File blobFile;
  final File keyFile;
}

class ShareService {
  ShareService({
    required DocumentOpenService opener,
    required DocumentImportService importer,
  })  : _opener = opener,
        _importer = importer;

  final DocumentOpenService _opener;
  final DocumentImportService _importer;
  static const _uuid = Uuid();
  static const _formatVersion = 1;

  Future<ShareExport> exportDocument(Document doc) async {
    final plaintext = await _opener.decryptBytes(doc);

    final shareDek = await AesGcm.with256bits().newSecretKey();
    final sealed = await Aead.seal(key: shareDek, plaintext: plaintext);

    final dir = await _shareDir();
    final stem = _stem(doc.originalName);
    final blobFile = File(p.join(dir.path, '$stem.sdkblob'));
    final keyFile = File(p.join(dir.path, '$stem.sdkkey.json'));

    await blobFile.writeAsBytes(sealed.ciphertext, flush: true);

    final keyMap = {
      'version': _formatVersion,
      'original_name': doc.originalName,
      'mime_type': doc.mimeType,
      'size': plaintext.length,
      'dek': base64Encode(await shareDek.extractBytes()),
      'nonce': base64Encode(sealed.nonce),
      'mac': base64Encode(sealed.mac),
    };
    await keyFile.writeAsString(jsonEncode(keyMap), flush: true);

    return ShareExport(blobFile: blobFile, keyFile: keyFile);
  }

  Future<void> shareViaSystem(ShareExport export) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(export.blobFile.path),
          XFile(export.keyFile.path),
        ],
        text: 'Encrypted document. Send the .sdkkey.json over a separate channel.',
      ),
    );
  }

  Future<Document> importPackage({
    required File blobFile,
    required File keyFile,
  }) async {
    final keyJson = jsonDecode(await keyFile.readAsString()) as Map<String, Object?>;
    final version = keyJson['version'] as int?;
    if (version != _formatVersion) {
      throw FormatException('Unsupported share format version: $version');
    }
    final originalName = keyJson['original_name'] as String? ?? 'imported';
    final mimeType = keyJson['mime_type'] as String?;
    final dekBytes = base64Decode(keyJson['dek']! as String);
    final nonce = base64Decode(keyJson['nonce']! as String);
    final mac = base64Decode(keyJson['mac']! as String);

    final ciphertext = await blobFile.readAsBytes();
    final plaintext = await Aead.open(
      key: SecretKey(dekBytes),
      sealed: SealedBytes(
        nonce: Uint8List.fromList(nonce),
        ciphertext: Uint8List.fromList(ciphertext),
        mac: Uint8List.fromList(mac),
      ),
    );

    return _importer.importBytes(
      bytes: plaintext,
      originalName: originalName,
      mimeType: mimeType,
    );
  }

  Future<Directory> _shareDir() async {
    final tmp = await getTemporaryDirectory();
    final out = Directory(p.join(tmp.path, 'sdk_share', _uuid.v4()));
    out.createSync(recursive: true);
    return out;
  }

  String _stem(String name) {
    final base = p.basenameWithoutExtension(name);
    return base.isEmpty ? 'document' : base;
  }
}
