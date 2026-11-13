import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/order_repository.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/features/admin/admin_screen.dart';
import 'package:orderacoffee/frontend/features/admin/widgets/order_details_modal.dart';
import 'package:orderacoffee/frontend/features/menu/menu_provider.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';

class _FakeOrderRepository extends OrderRepository {
  String? assignedOrderId;
  String? assignedDriverId;

  @override
  Future<void> assignDriver(
    String orderId, {
    required String driverId,
    required String driverName,
    String? driverPhone,
  }) async {
    assignedOrderId = orderId;
    assignedDriverId = driverId;
  }
}

void main() {
  group('Admin Authentication & Provisioning Tests', () {
    test('Default admin email and UID constants are defined without hardcoded password', () {
      expect(AuthRepository.defaultAdminEmail, equals('admin@cafego.ph'));
      expect(AuthRepository.defaultAdminPassword, isEmpty);
      expect(AuthRepository.defaultAdminUid, equals('admin-master'));
    });

    test('Admin user profile role and permissions check', () {
      const admin = UserProfile(
        uid: AuthRepository.defaultAdminUid,
        name: 'Master Admin',
        email: AuthRepository.defaultAdminEmail,
        phone: '+63 917 000 0001',
        role: 'admin',
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isStaff, isTrue);
      expect(admin.isCustomer, isFalse);
    });
  });

  group('Admin Console Screen Widget Tests', () {
    final testMenuItems = [
      const MenuItem(
        id: 'item_spanish_latte',
        name: 'Spanish Latte',
        category: 'Hot Coffee',
        description: 'Espresso with condensed milk and steamed fresh milk.',
        basePrice: 170.0,
        isAvailable: true,
        isHidden: false,
      ),
      const MenuItem(
        id: 'item_cold_brew',
        name: 'Signature Cold Brew',
        category: 'Iced Coffee',
        description: 'Steeped for 18 hours for deep flavor.',
        basePrice: 160.0,
        isAvailable: false,
        isHidden: false,
      ),
    ];

    final List<Order> testOrders = [
      Order(
        id: 'ORD-9001',
        userId: 'customer_1',
        userName: 'Maria Santos',
        items: const [
          OrderItem(
            itemId: 'item_spanish_latte',
            name: 'Spanish Latte',
            unitPrice: 170.0,
            qty: 1,
          ),
        ],
        subtotal: 170.0,
        deliveryFee: 0.0,
        total: 170.0,
        type: OrderType.pickup,
        status: OrderStatus.received,
        payment: PaymentMethod.counter,
        paymentStatus: PaymentStatus.pending,
        createdAt: DateTime.now(),
      ),
    ];

    Widget createAdminTestWidget() {
      return ProviderScope(
        overrides: [
          menuStreamProvider.overrideWith((ref) => Stream.value(testMenuItems)),
          allMenuStreamProvider.overrideWith((ref) => Stream.value(testMenuItems)),
          liveQueueStreamProvider.overrideWith((ref) => Stream.value(testOrders)),
          allOrdersStreamProvider.overrideWith((ref) => Stream.value(testOrders)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminScreen(),
          ),
        ),
      );
    }

    testWidgets('Renders Admin Header, Brand pill, and all 4 Segmented Tabs', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Top Admin Header
      expect(find.text('ADMIN CONSOLE'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      // 4 Segmented Tabs
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Staff/Users'), findsOneWidget);
    });

    testWidgets('Orders tab renders active order with customer name and suppresses UUID', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Check order shows only customer name and suppresses raw UUID
      expect(find.textContaining('Maria Santos'), findsOneWidget);
      expect(find.textContaining('ORD-9001'), findsNothing);

      // Check status chips
      expect(find.textContaining('All'), findsWidgets);
      expect(find.textContaining('Received'), findsWidgets);
    });

    testWidgets('Tapping order opens Order Details Modal', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Tap the order card
      await tester.tap(find.text('Maria Santos'));
      await tester.pumpAndSettle();

      // Modal should display customer name and items
      expect(find.text('Items Ordered (1)'), findsOneWidget);
      expect(find.text('1x Spanish Latte'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
    });

    testWidgets('Switching to Catalog tab renders menu products and Add Item button', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Tap "Catalog" tab
      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();

      // Check Add Item button and products
      expect(find.byKey(const Key('adminAddProductButton')), findsOneWidget);
      expect(find.text('Spanish Latte'), findsOneWidget);
      expect(find.text('Signature Cold Brew'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('Sold Out'), findsOneWidget);

      // Tap Add Item button to open dialog
      await tester.tap(find.byKey(const Key('adminAddProductButton')));
      await tester.pumpAndSettle();

      expect(find.text('Add New Product'), findsOneWidget);
      expect(find.text('Upload Picture'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Switching to Analytics tab renders Financial Overview cards and dashboard graphs', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Tap "Analytics" tab
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('Financial Overview'), findsOneWidget);
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text('Average Order Value'), findsOneWidget);
      expect(find.text('Active in Queue'), findsOneWidget);

      // Verify dashboard charts
      expect(find.text('Hourly Revenue & Demand'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Sales by Menu Category'), 100);
      expect(find.text('Sales by Menu Category'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Fulfillment Status Distribution'), 100);
      expect(find.text('Fulfillment Status Distribution'), findsOneWidget);
    });

    testWidgets('Switching to Staff/Users tab renders directory header and role dialog includes DRIVER', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            menuStreamProvider.overrideWith((ref) => Stream.value(testMenuItems)),
            allMenuStreamProvider.overrideWith((ref) => Stream.value(testMenuItems)),
            liveQueueStreamProvider.overrideWith((ref) => Stream.value(testOrders)),
            allOrdersStreamProvider.overrideWith((ref) => Stream.value(testOrders)),
            allUsersStreamProvider.overrideWith((ref) => Stream.value(const [
                  UserProfile(
                    uid: 'user-1',
                    name: 'Juan Dela Cruz',
                    email: 'juan@cafego.ph',
                    phone: '+63 917 111 2222',
                    role: 'customer',
                  ),
                ])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Staff/Users" tab
      await tester.tap(find.text('Staff/Users'));
      await tester.pumpAndSettle();

      expect(find.text('Accounts & Staff Directory'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);

      await tester.tap(find.byTooltip('Change role'));
      await tester.pumpAndSettle();

      expect(find.text('CUSTOMER'), findsWidgets);
      expect(find.text('STAFF'), findsOneWidget);
      expect(find.text('DRIVER'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
    });

    testWidgets('OrderDetailsModal driver assignment shows phone fallback and SnackBar', (tester) async {
      final fakeOrderRepo = _FakeOrderRepository();
      final deliveryOrder = Order(
        id: 'ORD-DEL-1',
        userId: 'customer_1',
        userName: 'Maria Santos',
        items: const [
          OrderItem(
            itemId: 'item_spanish_latte',
            name: 'Spanish Latte',
            unitPrice: 170.0,
            qty: 1,
          ),
        ],
        subtotal: 170.0,
        deliveryFee: 50.0,
        total: 220.0,
        type: OrderType.delivery,
        status: OrderStatus.preparing,
        payment: PaymentMethod.cash,
        paymentStatus: PaymentStatus.pending,
        createdAt: DateTime.now(),
      );
      const driverWithoutPhone = UserProfile(
        uid: 'driver-1',
        name: 'Driver One',
        email: 'driver1@cafego.ph',
        phone: '',
        role: 'driver',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(fakeOrderRepo),
            allUsersStreamProvider.overrideWith((ref) => Stream.value([driverWithoutPhone])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OrderDetailsModal(order: deliveryOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();

      expect(find.text('Driver One'), findsOneWidget);
      expect(find.text('No phone • Motorcycle'), findsOneWidget);

      await tester.tap(find.text('Driver One'));
      await tester.pumpAndSettle();

      expect(fakeOrderRepo.assignedOrderId, 'ORD-DEL-1');
      expect(fakeOrderRepo.assignedDriverId, 'driver-1');
      expect(find.text('Assigned delivery to Driver One'), findsOneWidget);
    });
  });
}
