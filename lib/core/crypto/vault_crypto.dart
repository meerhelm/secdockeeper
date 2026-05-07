import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'aead.dart';
import 'kdf.dart';

class WrappedDek {
  const WrappedDek({required this.nonce, required this.ciphertext, required this.mac});

  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;
}

class VaultCrypto {
  Future<SecretKey> generateDek() async {
    final bytes = randomBytes(32);
    return SecretKey(bytes);
  }

  Future<WrappedDek> wrapDek({
    required SecretKey kek,
    required SecretKey dek,
  }) async {
    final dekBytes = await dek.extractBytes();
    final sealed = await Aead.seal(key: kek, plaintext: dekBytes);
    return WrappedDek(
      nonce: sealed.nonce,
      ciphertext: sealed.ciphertext,
      mac: sealed.mac,
    );
  }

  Future<SecretKey> unwrapDek({
    required SecretKey kek,
    required WrappedDek wrapped,
  }) async {
    final bytes = await Aead.open(
      key: kek,
      sealed: SealedBytes(
        nonce: wrapped.nonce,
        ciphertext: wrapped.ciphertext,
        mac: wrapped.mac,
      ),
    );
    return SecretKey(bytes);
  }

  Future<SealedBytes> encryptBlob({
    required SecretKey dek,
    required List<int> plaintext,
    List<int>? aad,
  }) {
    return Aead.seal(key: dek, plaintext: plaintext, aad: aad);
  }

  Future<Uint8List> decryptBlob({
    required SecretKey dek,
    required SealedBytes sealed,
    List<int>? aad,
  }) {
    return Aead.open(key: dek, sealed: sealed, aad: aad);
  }
}
