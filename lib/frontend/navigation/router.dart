import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:orderacoffee/frontend/features/admin/admin_screen.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/auth/email_verification_screen.dart';
import 'package:orderacoffee/frontend/features/auth/login_screen.dart';
import 'package:orderacoffee/frontend/features/auth/signup_screen.dart';
import 'package:orderacoffee/frontend/features/cart/cart_screen.dart';
import 'package:orderacoffee/frontend/features/checkout/checkout_screen.dart';
import 'package:orderacoffee/frontend/features/landing/landing_screen.dart';
import 'package:orderacoffee/frontend/features/menu/menu_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_history_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_receipt_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_tracking_screen.dart';
import 'package:orderacoffee/frontend/features/profile/profile_screen.dart';
import 'package:orderacoffee/frontend/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggedIn = authState.isAuthenticated;
    final isStaff = authState.isAdmin || authState.profile?.role == 'staff';
    final path = state.uri.path;
    final isAuthRoute = path == '/landing' ||
        path == '/login' ||
        path == '/signup' ||
        path == '/verify-email';

    // If not logged in and trying to access protected screens, start at landing/login
    if (!isLoggedIn && !isAuthRoute) {
      return '/landing';
    }

    // If already logged in and navigating to auth screens (except landing), route appropriately
    if (isLoggedIn && (path == '/login' || path == '/signup')) {
      return isStaff ? '/admin' : '/';
    }

    // Role guard: prevent non-staff/non-admin users from accessing /admin
    if (isLoggedIn && path.startsWith('/admin') && !isStaff) {
      return '/';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/landing',
    refreshListenable: routerNotifier,
    redirect: routerNotifier.redirect,
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MenuScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrderHistoryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/order/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderTrackingScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/order-receipt/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OrderReceiptScreen(orderId: id);
        },
      ),
    ],
  );
});
