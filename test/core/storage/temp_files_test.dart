import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/core/storage/temp_files.dart';

void main() {
  group('sanitizeFileName', () {
    test('keeps ordinary names', () {
      expect(sanitizeFileName('Паспорт скан.pdf'), 'Паспорт скан.pdf');
    });

    test('strips directory traversal', () {
      expect(sanitizeFileName('../../files/secdockeeper/vault.json'), 'vault.json');
      expect(sanitizeFileName(r'..\..\vault.json'), 'vault.json');
      expect(sanitizeFileName('/etc/passwd'), 'passwd');
    });

    test('falls back for names with no usable segment', () {
      expect(sanitizeFileName('..'), 'document');
      expect(sanitizeFileName('.'), 'document');
      expect(sanitizeFileName('../'), 'document');
      expect(sanitizeFileName(''), 'document');
      expect(sanitizeFileName('\u0000\n'), 'document');
    });
  });
}
