import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/features/vault/vault_descriptor.dart';

void main() {
  test('WrappedVmk survives a JSON round-trip', () {
    final original = WrappedVmk(
      nonce: Uint8List.fromList(List.generate(12, (i) => i)),
      ciphertext: Uint8List.fromList(List.generate(32, (i) => 255 - i)),
      mac: Uint8List.fromList(List.generate(16, (i) => i * 2)),
    );

    final restored = WrappedVmk.fromJson(original.toJson());

    expect(restored.nonce, original.nonce);
    expect(restored.ciphertext, original.ciphertext);
    expect(restored.mac, original.mac);
  });

  test('createFresh produces a complete-able version-2 descriptor', () {
    final d = VaultDescriptor.createFresh();
    expect(d.version, VaultDescriptor.currentVersion);
    expect(d.version, 2);
    expect(d.salt.length, 16);
    // No VMK until the caller wraps one.
    expect(d.usesVmk, isFalse);

    final withVmk = d.withWrappedVmk(WrappedVmk(
      nonce: Uint8List(12),
      ciphertext: Uint8List(32),
      mac: Uint8List(16),
    ));
    expect(withVmk.usesVmk, isTrue);
  });
}
