import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/backend/services/security.dart';

void main() {
  group('Security Tests', () {
    test('hashPassword generates consistent 64-character SHA-256 hex string', () {
      final hash1 = hashPassword('MySecretPass123!', salt: 'user-uid-1');
      final hash2 = hashPassword('MySecretPass123!', salt: 'user-uid-1');

      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash1), isTrue);
    });

    test('hashPassword produces different hashes for different salts', () {
      final hash1 = hashPassword('MySecretPass123!', salt: 'user-uid-1');
      final hash2 = hashPassword('MySecretPass123!', salt: 'user-uid-2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPassword does not contain the original password in plaintext', () {
      const pass = 'PlaintextPassword123';
      final hash = hashPassword(pass, salt: 'user-salt');

      expect(hash.contains(pass), isFalse);
    });
  });
}
