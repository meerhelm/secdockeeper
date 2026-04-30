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
    memory: 19 * 1024,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  );

  Map<String, Object?> toJson() => {
        'm': memory,
        't': iterations,
        'p': parallelism,
        'h': hashLength,
      };

  factory KdfParams.fromJson(Map<String, Object?> json) => KdfParams(
        memory: json['m']! as int,
        iterations: json['t']! as int,
        parallelism: json['p']! as int,
        hashLength: json['h']! as int,
      );
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
