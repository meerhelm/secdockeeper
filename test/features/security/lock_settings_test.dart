import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/features/security/lock_settings.dart';

void main() {
  group('LockSettings.lockoutDurationFor', () {
    test('first hit (3 fails) → 10 minutes', () {
      expect(LockSettings.lockoutDurationFor(3), const Duration(minutes: 10));
    });

    test('second hit (6 fails) → 30 minutes', () {
      expect(LockSettings.lockoutDurationFor(6), const Duration(minutes: 30));
    });

    test('third hit (9 fails) → 1 hour', () {
      expect(LockSettings.lockoutDurationFor(9), const Duration(hours: 1));
    });

    test('fourth hit and beyond (12+ fails) → 1 day', () {
      expect(LockSettings.lockoutDurationFor(12), const Duration(days: 1));
      expect(LockSettings.lockoutDurationFor(99), const Duration(days: 1));
    });
  });
}
