import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/core/crypto/aead.dart';
import 'package:secdockeeper/core/crypto/vault_crypto.dart';
import 'package:secdockeeper/core/crypto/vault_keys.dart';

void main() {
  final crypto = VaultCrypto();

  Future<SecretKey> key() => AesGcm.with256bits().newSecretKey();

  group('rowAad', () {
    test('is null for legacy v1 rows', () {
      expect(rowAad(formatVersion: 1, uuid: 'abc'), isNull);
    });
    test('is the uuid bytes for v2 rows', () {
      expect(rowAad(formatVersion: 2, uuid: 'abc'), 'abc'.codeUnits);
    });
  });

  group('AAD-bound DEK wrap', () {
    test('round-trips when the same AAD is supplied', () async {
      final kek = await key();
      final dek = await crypto.generateDek();
      final aad = rowAad(formatVersion: 2, uuid: 'doc-uuid');

      final wrapped = await crypto.wrapDek(kek: kek, dek: dek, aad: aad);
      final unwrapped = await crypto.unwrapDek(kek: kek, wrapped: wrapped, aad: aad);

      expect(await unwrapped.extractBytes(), await dek.extractBytes());
    });

    test('fails when the AAD (uuid) differs — blobs cannot be swapped', () async {
      final kek = await key();
      final dek = await crypto.generateDek();
      final wrapped = await crypto.wrapDek(
        kek: kek,
        dek: dek,
        aad: rowAad(formatVersion: 2, uuid: 'row-A'),
      );

      expect(
        () => crypto.unwrapDek(
          kek: kek,
          wrapped: wrapped,
          aad: rowAad(formatVersion: 2, uuid: 'row-B'),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('AAD-bound blob', () {
    test('round-trips and rejects a mismatched uuid', () async {
      final dek = await crypto.generateDek();
      final plaintext = Uint8List.fromList([1, 2, 3, 4]);
      final sealed = await crypto.encryptBlob(
        dek: dek,
        plaintext: plaintext,
        aad: rowAad(formatVersion: 2, uuid: 'row-A'),
      );

      final ok = await crypto.decryptBlob(
        dek: dek,
        sealed: SealedBytes(
          nonce: sealed.nonce,
          ciphertext: sealed.ciphertext,
          mac: sealed.mac,
        ),
        aad: rowAad(formatVersion: 2, uuid: 'row-A'),
      );
      expect(ok, plaintext);

      expect(
        () => crypto.decryptBlob(
          dek: dek,
          sealed: SealedBytes(
            nonce: sealed.nonce,
            ciphertext: sealed.ciphertext,
            mac: sealed.mac,
          ),
          aad: rowAad(formatVersion: 2, uuid: 'row-B'),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('key separation (M-1)', () {
    test('db key, wrap key are distinct derivations of the VMK', () async {
      final vmk = await AesGcm.with256bits().newSecretKey();
      final dbKey = await (await deriveDbKey(vmk)).extractBytes();
      final wrapKey = await (await deriveWrapKey(vmk)).extractBytes();
      final vmkBytes = await vmk.extractBytes();

      expect(dbKey, isNot(wrapKey));
      expect(dbKey, isNot(vmkBytes));
      expect(wrapKey, isNot(vmkBytes));
      expect(dbKey.length, 32);
      expect(wrapKey.length, 32);
    });
  });
}
