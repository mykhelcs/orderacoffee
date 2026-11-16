import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/loyalty_repository.dart';
import 'package:orderacoffee/backend/repositories/order_repository.dart';
import 'package:orderacoffee/backend/repositories/user_repository.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/cart/cart_provider.dart';
import 'package:orderacoffee/frontend/features/checkout/checkout_screen.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';

class _ThrowingOrderRepository extends OrderRepository {
  @override
  Future<String> placeOrder(OrderDraft draft, {String? orderId}) async {
    throw const ValidationFailure('Simulated backend checkout outage');
  }
}

class _SlowCountingOrderRepository extends OrderRepository {
  _SlowCountingOrderRepository({super.firestore});
  int callCount = 0;

  @override
  Future<String> placeOrder(OrderDraft draft, {String? orderId}) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return super.placeOrder(draft, orderId: orderId);
  }
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(
    super.authRepo,
    super.userRepo, {
    required UserProfile initialProfile,
    super.loyaltyRepo,
  }) {
    state = AuthState(profile: initialProfile);
  }
}

void main() {
  group('CheckoutScreen Widget Tests', () {
    testWidgets('renders CheckoutScreen with Scaffold and Material ancestors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );

      // Verify header and default order type (Pickup)
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Dine-in'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('tapping Dine-in renders Dine-in Service card without table input field', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );

      // Tap 'Dine-in'
      await tester.tap(find.text('Dine-in'));
      await tester.pumpAndSettle();

      // Check Dine-in info card is rendered without table number TextField
      expect(find.text('Dine-in Service'), findsOneWidget);
      expect(find.textContaining('Grab any comfortable seat'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping Delivery renders alphanumeric address TextField', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );

      // Tap 'Delivery'
      await tester.tap(find.text('Delivery'));
      await tester.pumpAndSettle();

      // Check delivery address textfield is rendered with normal text keyboard
      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.text);
      expect(textField.textCapitalization, TextCapitalization.words);
    });

    test('OrderRepository resilient placeOrder succeeds and creates local order with progression', () async {
      final repo = OrderRepository();
      const draft = OrderDraft(
        userId: 'test-user',
        userName: 'Coffee Lover',
        items: [
          OrderItem(
            itemId: 'item-1',
            name: 'Spanish Latte',
            qty: 1,
            unitPrice: 140,
          ),
        ],
        type: OrderType.dineIn,
        tableNo: 'Dine-in (Open Seating)',
      );

      final orderId = await repo.placeOrder(draft);
      expect(orderId.startsWith('ORD-'), isTrue);

      final order = await repo.getOrder(orderId);
      expect(order.id, orderId);
      expect(order.status, OrderStatus.received);
      expect(order.tableNo, 'Dine-in (Open Seating)');
      expect(order.total, 140.0);
    });

    testWidgets('rolls back redeemed stamps and preserves cart when placeOrder fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeFs = FakeFirebaseFirestore();
      final userRepo = UserRepository(firestore: fakeFs);
      final loyaltyRepo = LoyaltyRepository(firestore: fakeFs);
      final mockUser = MockUser(
        uid: 'cust-loyalty-1',
        email: 'maria@cafego.ph',
        displayName: 'Maria',
      );
      final authRepo = AuthRepository(
        auth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
        firestore: fakeFs,
      );

      const userProfile = UserProfile(
        uid: 'cust-loyalty-1',
        name: 'Maria',
        email: 'maria@cafego.ph',
        phone: '+63 917 000 1111',
        role: 'customer',
        stamps: 8,
      );
      await userRepo.createProfile(userProfile);

      final cartNotifier = CartNotifier();
      cartNotifier.addLine(
        const MenuItem(
          id: 'latte',
          name: 'Latte',
          category: 'Hot Coffee',
          description: 'Smooth',
          basePrice: 160.0,
        ),
        const CartCustomizations(),
        1,
      );

      final authNotifier = _TestAuthNotifier(
        authRepo,
        userRepo,
        initialProfile: userProfile,
        loyaltyRepo: loyaltyRepo,
      );

      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(_ThrowingOrderRepository()),
          cartProvider.overrideWith((ref) => cartNotifier),
          authProvider.overrideWith((ref) => authNotifier),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable loyalty stamp redemption switch
      final loyaltySwitch = find.byType(Switch);
      await tester.ensureVisible(loyaltySwitch);
      await tester.tap(loyaltySwitch);
      await tester.pumpAndSettle();

      // Tap Place order (which fails via _ThrowingOrderRepository)
      final placeBtn = find.text('Place order');
      await tester.ensureVisible(placeBtn);
      await tester.tap(placeBtn);
      await tester.pumpAndSettle();

      // Stamps must NOT be lost, earnStamp must NOT be added, and cart must remain intact
      expect(container.read(authProvider).profile?.stamps, 8);
      final userDoc = await fakeFs.collection('users').doc(userProfile.uid).get();
      expect(userDoc.data()?['stamps'], 8);
      expect(container.read(cartProvider).lines.length, 1);
      expect(find.textContaining('Failed to place order'), findsOneWidget);
    });

    testWidgets('ignores duplicate Place order taps while an order submission is in flight', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeFs = FakeFirebaseFirestore();
      final orderRepo = _SlowCountingOrderRepository(firestore: fakeFs);
      final cartNotifier = CartNotifier();
      cartNotifier.addLine(
        const MenuItem(
          id: 'espresso',
          name: 'Espresso',
          category: 'Hot Coffee',
          description: 'Single shot',
          basePrice: 110.0,
        ),
        const CartCustomizations(),
        1,
      );

      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orderRepo),
          cartProvider.overrideWith((ref) => cartNotifier),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/checkout',
        routes: [
          GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
          GoRoute(
            path: '/order-receipt/:id',
            builder: (_, __) => const Scaffold(body: Text('Receipt Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Place order twice before the async request resolves
      final placeBtn = find.byType(BrandButton);
      await tester.tap(placeBtn);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(placeBtn);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(orderRepo.callCount, 1);
      expect(find.text('Receipt Screen'), findsOneWidget);
    });
  });
}
