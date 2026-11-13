import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/navigation/router.dart';

class _TestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuthNotifier([super.initial = const AuthState()]);

  void setProfile(UserProfile? profile) {
    state = AuthState(profile: profile);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Router Guard & RBAC Tests', () {
    Widget createRouterTestApp(_TestAuthNotifier notifier, {String initialLocation = '/landing'}) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => notifier),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = GoRouter(
              initialLocation: initialLocation,
              refreshListenable: ref.watch(routerNotifierProvider),
              redirect: ref.read(routerNotifierProvider).redirect,
              routes: [
                GoRoute(path: '/landing', builder: (_, __) => const Text('PAGE_LANDING')),
                GoRoute(path: '/login', builder: (_, __) => const Text('PAGE_LOGIN')),
                GoRoute(path: '/signup', builder: (_, __) => const Text('PAGE_SIGNUP')),
                GoRoute(path: '/verify-email', builder: (_, __) => const Text('PAGE_VERIFY')),
                GoRoute(path: '/', builder: (_, __) => const Text('PAGE_MENU')),
                GoRoute(path: '/cart', builder: (_, __) => const Text('PAGE_CART')),
                GoRoute(path: '/checkout', builder: (_, __) => const Text('PAGE_CHECKOUT')),
                GoRoute(path: '/orders', builder: (_, __) => const Text('PAGE_ORDERS')),
                GoRoute(path: '/admin', builder: (_, __) => const Text('PAGE_ADMIN')),
                GoRoute(path: '/staff', builder: (_, __) => const Text('PAGE_STAFF')),
                GoRoute(path: '/driver', builder: (_, __) => const Text('PAGE_DRIVER')),
              ],
            );
            return MaterialApp.router(routerConfig: router);
          },
        ),
      );
    }

    testWidgets('unauthenticated user accessing protected routes redirects to /landing', (tester) async {
      final notifier = _TestAuthNotifier();
      await tester.pumpWidget(createRouterTestApp(notifier, initialLocation: '/admin'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE_LANDING'), findsOneWidget);
    });

    testWidgets('customer cannot access /admin, /staff, or /driver and lands on /', (tester) async {
      final notifier = _TestAuthNotifier(
        const AuthState(
          profile: UserProfile(
            uid: 'c1',
            name: 'Cust',
            email: 'cust@cafego.ph',
            phone: '+639171234567',
            role: 'customer',
          ),
        ),
      );

      for (final forbidden in ['/admin', '/staff', '/driver', '/login']) {
        await tester.pumpWidget(createRouterTestApp(notifier, initialLocation: forbidden));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_MENU'), findsOneWidget, reason: 'Expected / for $forbidden');
      }
    });

    testWidgets('staff is restricted to /staff and blocked from /admin, /driver, and /', (tester) async {
      final notifier = _TestAuthNotifier(
        const AuthState(
          profile: UserProfile(
            uid: 's1',
            name: 'Staff',
            email: 'staff@cafego.ph',
            phone: '+639171234567',
            role: 'staff',
          ),
        ),
      );

      for (final route in ['/admin', '/driver', '/', '/checkout', '/login']) {
        await tester.pumpWidget(createRouterTestApp(notifier, initialLocation: route));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_STAFF'), findsOneWidget, reason: 'Expected /staff for $route');
      }
    });

    testWidgets('driver is restricted to /driver and blocked from /admin, /staff, and /', (tester) async {
      final notifier = _TestAuthNotifier(
        const AuthState(
          profile: UserProfile(
            uid: 'd1',
            name: 'Driver',
            email: 'driver@cafego.ph',
            phone: '+639171234567',
            role: 'driver',
          ),
        ),
      );

      for (final route in ['/admin', '/staff', '/', '/checkout', '/login']) {
        await tester.pumpWidget(createRouterTestApp(notifier, initialLocation: route));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_DRIVER'), findsOneWidget, reason: 'Expected /driver for $route');
      }
    });

    testWidgets('admin is restricted to /admin and blocked from /staff, /driver, and /', (tester) async {
      final notifier = _TestAuthNotifier(
        const AuthState(
          profile: UserProfile(
            uid: 'a1',
            name: 'Admin',
            email: 'admin@cafego.ph',
            phone: '+639171234567',
            role: 'admin',
          ),
        ),
      );

      for (final route in ['/staff', '/driver', '/', '/checkout', '/login']) {
        await tester.pumpWidget(createRouterTestApp(notifier, initialLocation: route));
        await tester.pumpAndSettle();
        expect(find.text('PAGE_ADMIN'), findsOneWidget, reason: 'Expected /admin for $route');
      }
    });
  });
}
