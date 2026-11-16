import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/cart_repository.dart';
import 'package:orderacoffee/backend/repositories/loyalty_repository.dart';
import 'package:orderacoffee/backend/repositories/menu_repository.dart';
import 'package:orderacoffee/backend/repositories/order_repository.dart';
import 'package:orderacoffee/backend/repositories/rating_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/cart/cart_provider.dart';
import 'package:orderacoffee/frontend/features/checkout/checkout_screen.dart';
import 'package:orderacoffee/frontend/features/driver/driver_screen.dart';
import 'package:orderacoffee/frontend/features/menu/menu_provider.dart';
import 'package:orderacoffee/frontend/features/orders/order_receipt_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_tracking_screen.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/features/orders/rating_provider.dart';
import 'package:orderacoffee/frontend/features/staff/staff_screen.dart';

class _RoleAuthNotifier extends AuthNotifier {
  _RoleAuthNotifier(
    super.authRepo,
    super.userRepo, {
    required UserProfile profile,
    super.loyaltyRepo,
  }) {
    state = AuthState(profile: profile);
  }

  void switchProfile(UserProfile profile) {
    state = AuthState(profile: profile);
  }
}

void main() {
  group('End-to-End Multi-Role Coffee Shop Ordering Flow', () {
    testWidgets(
      'Customer Checkout -> Staff KDS -> Driver Delivery -> Customer Rating, Receipt & Reorder',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final fakeFs = FakeFirebaseFirestore();
        final menuRepo = MenuRepository(firestore: fakeFs);
        final orderRepo = OrderRepository(firestore: fakeFs);
        final userRepo = UserRepository(firestore: fakeFs);
        final loyaltyRepo = LoyaltyRepository(firestore: fakeFs);
        final ratingRepo = RatingRepository(firestore: fakeFs);
        final cartRepo = CartRepository(prefs: prefs);

        const customer = UserProfile(
          uid: 'cust-e2e-1',
          name: 'Elena Gilbert',
          email: 'elena@cafego.ph',
          phone: '+63 917 222 3333',
          role: 'customer',
          stamps: 2,
        );
        const staff = UserProfile(
          uid: 'staff-e2e-1',
          name: 'Barista Leo',
          email: 'staff@cafego.ph',
          phone: '+63 917 444 5555',
          role: 'staff',
        );
        const driver = UserProfile(
          uid: 'driver-e2e-1',
          name: 'Rider Marco',
          email: 'driver@cafego.ph',
          phone: '+63 917 666 7777',
          role: 'driver',
          vehicleType: 'motorcycle',
          vehicleNumber: 'NCR-4321',
          isAvailable: true,
        );

        await userRepo.createProfile(customer);
        await userRepo.createProfile(staff);
        await userRepo.createProfile(driver);

        final latteId = await menuRepo.createItem(const MenuItem(
          id: 'spanish-latte',
          name: 'Spanish Latte',
          category: 'Hot Coffee',
          description: 'Espresso with condensed milk',
          basePrice: 170.0,
          isAvailable: true,
        ));
        final pastryId = await menuRepo.createItem(const MenuItem(
          id: 'almond-croissant',
          name: 'Almond Croissant',
          category: 'Pastries',
          description: 'Flaky croissant',
          basePrice: 120.0,
          isAvailable: true,
        ));

        final authRepo = AuthRepository(
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: customer.uid,
              email: customer.email,
              displayName: customer.name,
            ),
          ),
          firestore: fakeFs,
        );

        final authNotifier = _RoleAuthNotifier(
          authRepo,
          userRepo,
          profile: customer,
          loyaltyRepo: loyaltyRepo,
        );

        final cartNotifier = CartNotifier();
        cartNotifier.addLine(
          MenuItem(
            id: latteId,
            name: 'Spanish Latte',
            category: 'Hot Coffee',
            description: 'Espresso with condensed milk',
            basePrice: 170.0,
          ),
          const CartCustomizations(
            size: SizeOption(label: 'Large', delta: 20),
            milk: MilkOption(label: 'Oat', delta: 25),
            shots: 2,
            addOns: [AddOnOption(label: 'Extra shot', price: 30)],
          ),
          1,
          note: 'Less sweet',
        );
        cartNotifier.addLine(
          MenuItem(
            id: pastryId,
            name: 'Almond Croissant',
            category: 'Pastries',
            description: 'Flaky croissant',
            basePrice: 120.0,
          ),
          const CartCustomizations(),
          1,
        );

        // Subtotal = (170 + 20 + 25 + 30) + 120 = 365.0
        expect(cartNotifier.state.total, 365.0);

        String currentOrderId = '';

        final router = GoRouter(
          initialLocation: '/checkout',
          routes: [
            GoRoute(
              path: '/checkout',
              builder: (_, __) => const CheckoutScreen(),
            ),
            GoRoute(
              path: '/staff',
              builder: (_, __) => const StaffScreen(),
            ),
            GoRoute(
              path: '/driver',
              builder: (_, __) => const DriverScreen(),
            ),
            GoRoute(
              path: '/order/:id',
              builder: (_, state) {
                currentOrderId = state.pathParameters['id'] ?? '';
                return OrderTrackingScreen(orderId: currentOrderId);
              },
            ),
            GoRoute(
              path: '/order-receipt/:id',
              builder: (_, state) => OrderReceiptScreen(
                orderId: state.pathParameters['id'] ?? '',
              ),
            ),
          ],
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            userRepositoryProvider.overrideWithValue(userRepo),
            orderRepositoryProvider.overrideWithValue(orderRepo),
            menuRepositoryProvider.overrideWithValue(menuRepo),
            ratingRepositoryProvider.overrideWithValue(ratingRepo),
            authProvider.overrideWith((ref) => authNotifier),
            cartProvider.overrideWith((ref) => cartNotifier),
          ],
        );
        addTearDown(() {
          cartRepo.dispose();
          container.dispose();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // ─── STEP 1: Customer places a Delivery (Cash on Delivery) order ───
        await tester.tap(find.text('Delivery'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Serendra Tower B Unit 14A',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Place order'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Navigated to OrderTrackingScreen, cart cleared, customer earned 1 stamp
        expect(currentOrderId, isNotEmpty);
        expect(container.read(cartProvider).lines, isEmpty);
        expect(container.read(authProvider).profile?.stamps, 3);
        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('Cancel Order'), findsOneWidget);

        // ─── STEP 2: Staff KDS receives ticket, preps, and marks Ready ─────
        authNotifier.switchProfile(staff);
        router.go('/staff');
        await tester.pumpAndSettle();

        expect(find.text('KITCHEN QUEUE (KDS)'), findsOneWidget);
        expect(find.text('Elena Gilbert'), findsOneWidget);
        expect(find.text('1x Spanish Latte'), findsOneWidget);
        expect(find.text('Note: Less sweet'), findsOneWidget);

        await tester.tap(find.text('Start Preparing'));
        await tester.pumpAndSettle();

        expect(find.text('Mark as Ready'), findsOneWidget);
        await tester.tap(find.text('Mark as Ready'));
        await tester.pumpAndSettle();

        var liveOrder = await orderRepo.getOrder(currentOrderId);
        expect(liveOrder.status, OrderStatus.ready);

        // ─── STEP 3: Driver accepts delivery, advances GPS, completes COD ──
        authNotifier.switchProfile(driver);
        router.go('/driver');
        await tester.pumpAndSettle();

        expect(find.text('Available Orders Pool (1)'), findsOneWidget);
        expect(find.text('Elena Gilbert'), findsOneWidget);

        await tester.tap(find.text('Accept Delivery'));
        await tester.pumpAndSettle();

        expect(find.text('ACTIVE DELIVERY IN PROGRESS'), findsOneWidget);
        await tester.tap(find.text('Advance GPS'));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Complete & Collect'));
        await tester.pumpAndSettle();

        // Real OrderRepository stream updates Driver trips & earnings immediately
        expect(find.text('1 trips'), findsOneWidget);
        expect(find.text('₱ 45'), findsOneWidget);

        liveOrder = await orderRepo.getOrder(currentOrderId);
        expect(liveOrder.status, OrderStatus.completed);
        expect(liveOrder.paymentStatus, PaymentStatus.paid);

        // ─── STEP 4: Customer views completed tracking, rates & checks receipt
        authNotifier.switchProfile(customer);
        router.go('/order/$currentOrderId');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // Rating bottom sheet auto-opens on completed order
        expect(find.text('How was your order?'), findsOneWidget);
        await tester.tap(find.text('Submit Review'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final avgRating = await ratingRepo.getAverageRating(currentOrderId);
        expect(avgRating, 5.0);

        // Receipt view shows line items & total
        router.go('/order-receipt/$currentOrderId');
        await tester.pumpAndSettle();
        expect(find.text('Order Receipt'), findsOneWidget);
        expect(find.text('Spanish Latte'), findsOneWidget);
        expect(find.text('Almond Croissant'), findsOneWidget);

        // ─── STEP 5: Reorder restores available item & flags sold-out item ──
        await menuRepo.toggleSoldOut(pastryId, false);
        final unavailable = await orderRepo.reorder(
          orderId: currentOrderId,
          cart: cartRepo,
          menu: menuRepo,
        );

        expect(unavailable, equals(['Almond Croissant']));
        expect(cartRepo.lines.length, 1);
        expect(cartRepo.lines.first.name, 'Spanish Latte');
        expect(cartRepo.lines.first.note, 'Less sweet');
      },
    );
  });
}
