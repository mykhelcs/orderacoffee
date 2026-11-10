import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/features/admin/admin_screen.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/menu/menu_provider.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';

void main() {
  group('Admin Authentication & Provisioning Tests', () {
    test('Default admin credentials constants are defined and standard', () {
      expect(AuthRepository.defaultAdminEmail, equals('admin@cafego.ph'));
      expect(AuthRepository.defaultAdminPassword, equals('Admin@CafeGo2024!'));
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

    testWidgets('Orders tab renders active order with customer name and status filter chips', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Check order
      expect(find.textContaining('Maria Santos'), findsOneWidget);
      expect(find.textContaining('ORD-9001'), findsOneWidget);

      // Check status chips
      expect(find.textContaining('All'), findsWidgets);
      expect(find.textContaining('Received'), findsWidgets);
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
    });

    testWidgets('Switching to Analytics tab renders Financial Overview cards', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Tap "Analytics" tab
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('Financial Overview'), findsOneWidget);
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text('Average Order Value'), findsOneWidget);
      expect(find.text('Active in Queue'), findsOneWidget);
    });

    testWidgets('Switching to Staff/Users tab renders directory header', (tester) async {
      await tester.pumpWidget(createAdminTestWidget());
      await tester.pumpAndSettle();

      // Tap "Staff/Users" tab
      await tester.tap(find.text('Staff/Users'));
      await tester.pumpAndSettle();

      expect(find.text('Accounts & Staff Directory'), findsOneWidget);
    });
  });
}
