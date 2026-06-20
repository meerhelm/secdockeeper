import 'dart:convert';
import 'dart:isolate';
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

  static const hardenedParams = KdfParams(
    memory: 128 * 1024,
    iterations: 4,
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

/// User-facing Argon2id strength presets surfaced in Settings. The values
/// behind each preset live on [KdfParams] (defaultParams / hardenedParams).
enum KdfProfile {
  standard,
  hardened;

  KdfParams get params => switch (this) {
        KdfProfile.standard => KdfParams.defaultParams,
        KdfProfile.hardened => KdfParams.hardenedParams,
      };

  /// Classify a stored [KdfParams] against the known presets. Anything at or
  /// above the hardened threshold reads as [hardened]; otherwise [standard].
  static KdfProfile fromParams(KdfParams p) {
    final h = KdfParams.hardenedParams;
    if (p.memory >= h.memory && p.iterations >= h.iterations) {
      return KdfProfile.hardened;
    }
    return KdfProfile.standard;
  }
}

class Kdf {
  Kdf({KdfParams params = KdfParams.defaultParams}) : _params = params;

  final KdfParams _params;

  /// Derives the KEK with Argon2id on a background isolate so the
  /// memory-hard hash (64 MiB / t=3 by default) never blocks the UI thread.
  ///
  /// The isolate runs the pure-Dart Argon2id from `package:cryptography`
  /// (a spawned isolate does not inherit the root isolate's `Cryptography`
  /// backend, so this stays platform-channel-free and isolate-safe). AES-GCM
  /// elsewhere still benefits from the native backend enabled in `main()`.
  Future<SecretKey> deriveKek({
    required String password,
    required List<int> salt,
  }) async {
    final params = _params;
    final saltCopy = Uint8List.fromList(salt);
    final bytes = await Isolate.run(
      () => _deriveKekBytes(params, password, saltCopy),
    );
    return SecretKey(bytes);
  }

  static Future<Uint8List> _deriveKekBytes(
    KdfParams params,
    String password,
    Uint8List salt,
  ) async {
    final argon2 = Argon2id(
      memory: params.memory,
      parallelism: params.parallelism,
      iterations: params.iterations,
      hashLength: params.hashLength,
    );
    final key = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
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
