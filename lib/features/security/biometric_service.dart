import 'dart:io';

import 'package:local_auth/local_auth.dart';

enum BiometricKind { face, fingerprint, generic }

class BiometricService {
  BiometricService() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> get isAvailable async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } on LocalAuthException {
      return false;
    }
  }

  Future<List<BiometricType>> enrolledTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on LocalAuthException {
      return const [];
    }
  }

  Future<BiometricKind> resolveKind() async {
    final types = await enrolledTypes();
    if (types.contains(BiometricType.fingerprint)) return BiometricKind.fingerprint;
    if (types.contains(BiometricType.face)) return BiometricKind.face;
    return BiometricKind.generic;
  }

  Future<bool> authenticate({String reason = 'Unlock SecDockKeeper'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
