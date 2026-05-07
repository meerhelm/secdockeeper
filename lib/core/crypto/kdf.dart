import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class KdfParams {
  const KdfParams({
    required this.memory,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  final int memory;
  final int iterations;
  final int parallelism;
  final int hashLength;

  static const defaultParams = KdfParams(
    memory: 64 * 1024,
    iterations: 3,
    parallelism: 1,
    hashLength: 32,
  );

  // OWASP minimum floor — vaults persisted with weaker params are rejected on
  // load so a tampered vault.json cannot downgrade Argon2id strength.
  static const _minMemory = 19 * 1024;
  static const _minIterations = 2;
  static const _minParallelism = 1;
  static const _hashLength = 32;

  Map<String, Object?> toJson() => {
        'm': memory,
        't': iterations,
        'p': parallelism,
        'h': hashLength,
      };

  factory KdfParams.fromJson(Map<String, Object?> json) {
    final m = json['m']! as int;
    final t = json['t']! as int;
    final p = json['p']! as int;
    final h = json['h']! as int;
    if (m < _minMemory || t < _minIterations || p < _minParallelism || h != _hashLength) {
      throw const FormatException(
        'Vault KDF parameters fall below the minimum security floor.',
      );
    }
    return KdfParams(memory: m, iterations: t, parallelism: p, hashLength: h);
  }
}

class Kdf {
  Kdf({KdfParams params = KdfParams.defaultParams}) : _params = params;

  final KdfParams _params;

  Argon2id get _argon2 => Argon2id(
        memory: _params.memory,
        parallelism: _params.parallelism,
        iterations: _params.iterations,
        hashLength: _params.hashLength,
      );

  Future<SecretKey> deriveKek({
    required String password,
    required List<int> salt,
  }) async {
    return _argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}

final _secureRandom = Random.secure();

Uint8List randomBytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = _secureRandom.nextInt(256);
  }
  return out;
}
