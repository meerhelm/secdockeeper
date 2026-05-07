import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class TagHmac {
  TagHmac(this._secret);

  final SecretKey _secret;
  static final Hmac _hmac = Hmac.sha256();

  Future<Uint8List> hash(String tagName) async {
    final mac = await _hmac.calculateMac(
      utf8.encode(_normalize(tagName)),
      secretKey: _secret,
    );
    return Uint8List.fromList(mac.bytes);
  }

  static String _normalize(String s) => s.trim().toLowerCase();
}

Future<SecretKey> deriveTagHmacKey(SecretKey kek) async {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  return hkdf.deriveKey(
    secretKey: kek,
    info: utf8.encode('secdockeeper:hidden-tag-hmac:v1'),
    nonce: utf8.encode('secdockeeper:hkdf-salt:v1'),
  );
}
