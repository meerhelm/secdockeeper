import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// HKDF-SHA256 derivations of the working keys from the vault master key (VMK).
///
/// The VMK is a high-entropy random key, so a fixed salt is fine here — domain
/// separation comes from the `info` label. Each label yields an independent
/// 32-byte key so the SQLCipher passphrase, the DEK-wrapping key and the
/// hidden-tag HMAC key never coincide (finding M-1).
const _hkdfSalt = 'secdockeeper:hkdf-salt:v1';

Future<SecretKey> _derive(SecretKey vmk, String info) {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  return hkdf.deriveKey(
    secretKey: vmk,
    info: utf8.encode(info),
    nonce: utf8.encode(_hkdfSalt),
  );
}

/// Key whose base64 encoding is used as the SQLCipher passphrase (v2 vaults).
Future<SecretKey> deriveDbKey(SecretKey vmk) =>
    _derive(vmk, 'secdockeeper:db-key:v1');

/// Key that wraps per-document/-note DEKs and encrypts hidden-tag names (v2).
Future<SecretKey> deriveWrapKey(SecretKey vmk) =>
    _derive(vmk, 'secdockeeper:dek-wrap:v1');
