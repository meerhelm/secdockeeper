import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/core/storage/secure_temp.dart';

void main() {
  group('SecureTemp.safeName', () {
    test('passes through an ordinary file name', () {
      expect(SecureTemp.safeName('invoice.pdf'), 'invoice.pdf');
    });

    test('collapses POSIX path traversal to a basename', () {
      expect(SecureTemp.safeName('../../databases/vault.db'), 'vault.db');
    });

    test('collapses Windows-style traversal', () {
      expect(SecureTemp.safeName(r'..\..\vault.db'), 'vault.db');
    });

    test('strips any residual separators', () {
      expect(SecureTemp.safeName('a/b/c'), 'c');
      expect(SecureTemp.safeName(r'a\b\c'), 'c');
    });

    test('falls back to "document" for empty or dot names', () {
      expect(SecureTemp.safeName(''), 'document');
      expect(SecureTemp.safeName('.'), 'document');
      expect(SecureTemp.safeName('..'), 'document');
      expect(SecureTemp.safeName('/'), 'document');
    });
  });
}
