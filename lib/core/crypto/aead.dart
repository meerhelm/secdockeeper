import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class SealedBytes {
  const SealedBytes({required this.nonce, required this.ciphertext, required this.mac});

  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;
}

class Aead {
  Aead._();

  static final AesGcm _aesGcm = AesGcm.with256bits();

  static int get nonceLength => _aesGcm.nonceLength;

  static Future<SealedBytes> seal({
    required SecretKey key,
    required List<int> plaintext,
    List<int>? aad,
  }) async {
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return SealedBytes(
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  static Future<Uint8List> open({
    required SecretKey key,
    required SealedBytes sealed,
    List<int>? aad,
  }) async {
    final box = SecretBox(
      sealed.ciphertext,
      nonce: sealed.nonce,
      mac: Mac(sealed.mac),
    );
    final plaintext = await _aesGcm.decrypt(
      box,
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return Uint8List.fromList(plaintext);
  }
}
