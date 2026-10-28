import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';

void main() {
  group('AppException and subclasses', () {
    test('AuthFailure formatting with and without code', () {
      const f1 = AuthFailure('Invalid credentials', 'invalid-credential');
      expect(f1.toString(), 'AuthFailure (invalid-credential): Invalid credentials');

      const f2 = AuthFailure('Generic auth error');
      expect(f2.toString(), 'AuthFailure: Generic auth error');
    });

    test('ValidationFailure formatting', () {
      const vf = ValidationFailure('Invalid input');
      expect(vf.toString(), 'ValidationFailure: Invalid input');
    });

    test('NotFoundFailure formatting', () {
      const nf = NotFoundFailure('Resource missing');
      expect(nf.toString(), 'NotFoundFailure: Resource missing');
    });

    test('OrderStateFailure formatting', () {
      const osf = OrderStateFailure('Cannot cancel');
      expect(osf.toString(), 'OrderStateFailure: Cannot cancel');
    });

    test('PermissionFailure formatting', () {
      const pf = PermissionFailure('Unauthorized');
      expect(pf.toString(), 'PermissionFailure: Unauthorized');
    });
  });
}
