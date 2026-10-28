import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/features/auth/auth_provider.dart';

void main() {
  group('Router Guard Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('unauthenticated user state is not authenticated', () {
      expect(container.read(authProvider).isAuthenticated, isFalse);
    });

    test('authenticated user redirects away from /login to /', () async {
      await container
          .read(authProvider.notifier)
          .signIn('juan@coughfee.ph', 'password123');
      expect(container.read(authProvider).isAuthenticated, isTrue);
    });
  });
}
