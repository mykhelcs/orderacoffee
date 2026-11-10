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
import 'package:orderacoffee/frontend/features/driver/driver_screen.dart';
import 'package:orderacoffee/frontend/features/landing/landing_screen.dart';
import 'package:orderacoffee/frontend/features/menu/menu_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_history_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_receipt_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_tracking_screen.dart';
import 'package:orderacoffee/frontend/features/profile/profile_screen.dart';
import 'package:orderacoffee/frontend/features/staff/staff_screen.dart';
import 'package:orderacoffee/frontend/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.isAdmin != next.isAdmin ||
          previous?.profile?.role != next.profile?.role) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggedIn = authState.isAuthenticated;
    final role = authState.profile?.role;
    final isAdmin = role == 'admin';
    final isStaff = role == 'staff';
    final isDriver = role == 'driver';
    final isCustomer = role == 'customer';
    final path = state.uri.path;

    // Define public auth routes
    final isAuthRoute = path == '/landing' ||
        path == '/login' ||
        path == '/signup' ||
        path == '/verify-email';

    // Define role-specific route prefixes
    final isAdminPath = path.startsWith('/admin');
    final isStaffPath = path.startsWith('/staff');
    final isDriverPath = path.startsWith('/driver');
    final isCustomerPath =
        path == '/' || path.startsWith('/cart') || path.startsWith('/orders') || path.startsWith('/profile');

    // ─── Login/Auth Flow ──────────────────────────────────────────
    // If not logged in and trying to access protected screens, redirect to landing
    if (!isLoggedIn && !isAuthRoute) {
      return '/landing';
    }

    // If already logged in and trying to access auth screens, redirect to role dashboard
    if (isLoggedIn && (path == '/login' || path == '/signup')) {
      if (isAdmin) {
        return '/admin';
      } else if (isStaff) {
        return '/staff';
      } else if (isDriver) {
        return '/driver';
      } else {
        return '/';
      }
    }

    // ─── Strict Role-Based Access Control ──────────────────────────

    // Admin routes: only accessible by admin
    if (isLoggedIn && isAdminPath && !isAdmin) {
      return isStaff ? '/staff' : isDriver ? '/driver' : '/';
    }

    // Staff routes: only accessible by staff (not admin, not customer, not driver)
    if (isLoggedIn && isStaffPath && !(isStaff && !isAdmin)) {
      return isAdmin ? '/admin' : isDriver ? '/driver' : '/';
    }

    // Driver routes: only accessible by driver
    if (isLoggedIn && isDriverPath && !isDriver) {
      return isAdmin ? '/admin' : isStaff ? '/staff' : '/';
    }

    // Customer routes: only accessible by customer
    if (isLoggedIn && isCustomerPath && !isCustomer) {
      return isAdmin ? '/admin' : isStaff ? '/staff' : isDriver ? '/driver' : '/';
    }

    // Checkout and order tracking: prevent admin/staff from accessing
    if (isLoggedIn && (path.startsWith('/checkout') || path.startsWith('/order'))) {
      if (isAdmin || isStaff || isDriver) {
        return isAdmin ? '/admin' : isStaff ? '/staff' : '/driver';
      }
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
      // ──────────────────────────────────────────────────────────────
      // PUBLIC AUTH ROUTES (Shared by all roles)
      // ──────────────────────────────────────────────────────────────
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

      // ──────────────────────────────────────────────────────────────
      // CUSTOMER SHELL ROUTES (Shell with MainShell widget)
      // ──────────────────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Customer Home / Menu
          GoRoute(
            path: '/',
            builder: (context, state) => const MenuScreen(),
          ),
          // Customer Cart
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
          // Customer Orders
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrderHistoryScreen(),
          ),
          // Customer Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // ──────────────────────────────────────────────────────────────
      // ADMIN ROUTES (Admin-only dashboard)
      // ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminScreen(),
      ),

      // ──────────────────────────────────────────────────────────────
      // STAFF ROUTES (Kitchen Display System & Cashier)
      // ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/staff',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StaffScreen(),
      ),

      // ──────────────────────────────────────────────────────────────
      // DRIVER ROUTES (Delivery Cockpit & GPS)
      // ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/driver',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DriverScreen(),
      ),

      // ──────────────────────────────────────────────────────────────
      // CHECKOUT & ORDER TRACKING (Customer-only, outside shell)
      // ──────────────────────────────────────────────────────────────
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
