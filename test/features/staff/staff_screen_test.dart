import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/features/staff/staff_screen.dart';

void main() {
  group('StaffScreen Kitchen KDS Widget Tests', () {
    final testOrders = [
      Order(
        id: 'ORD-KITCHEN-1',
        userId: 'cust_1',
        userName: 'Carlos Yulo',
        items: const [
          OrderItem(
            itemId: 'item_spanish_latte',
            name: 'Spanish Latte',
            unitPrice: 170.0,
            qty: 2,
            note: 'Extra hot please',
          ),
        ],
        subtotal: 340.0,
        deliveryFee: 0.0,
        total: 340.0,
        type: OrderType.dineIn,
        tableNo: '7',
        status: OrderStatus.received,
        payment: PaymentMethod.counter,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      Order(
        id: 'ORD-KITCHEN-2',
        userId: 'cust_2',
        userName: 'EJ Obiena',
        items: const [
          OrderItem(
            itemId: 'item_cold_brew',
            name: 'Signature Cold Brew',
            unitPrice: 160.0,
            qty: 1,
          ),
        ],
        subtotal: 160.0,
        deliveryFee: 45.0,
        total: 205.0,
        type: OrderType.delivery,
        address: 'Olympic Village Tower 2',
        status: OrderStatus.preparing,
        payment: PaymentMethod.cash,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
    ];

    Widget createStaffTestWidget() {
      return ProviderScope(
        overrides: [
          liveQueueStreamProvider.overrideWith((ref) => Stream.value(testOrders)),
          allOrdersStreamProvider.overrideWith((ref) => Stream.value(testOrders)),
        ],
        child: const MaterialApp(
          home: StaffScreen(),
        ),
      );
    }

    testWidgets('Renders Staff KDS Header, live queue tickets, prep timers, and table numbers', (tester) async {
      await tester.pumpWidget(createStaffTestWidget());
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('KITCHEN QUEUE (KDS)'), findsOneWidget);

      // Status Pills
      expect(find.text('Received'), findsWidgets);
      expect(find.text('Preparing'), findsWidgets);
      expect(find.text('All Queue'), findsOneWidget);

      // Orders rendered FIFO
      expect(find.text('Carlos Yulo'), findsOneWidget);
      expect(find.text('EJ Obiena'), findsOneWidget);
      expect(find.textContaining('Table 7'), findsOneWidget);
      expect(find.textContaining('Note: Extra hot please'), findsOneWidget);

      // Contextual action buttons
      expect(find.text('Start Preparing'), findsOneWidget);
      expect(find.text('Mark as Ready'), findsOneWidget);
      expect(find.text('Receive Cash'), findsWidgets);
    });

    testWidgets('Tapping Receive Cash opens Cashier Drawer with change calculator', (tester) async {
      await tester.pumpWidget(createStaffTestWidget());
      await tester.pumpAndSettle();

      // Tap "Receive Cash" button on EJ Obiena order (₱205 - oldest in FIFO queue)
      await tester.tap(find.text('Receive Cash').first);
      await tester.pumpAndSettle();

      // Drawer modal open
      expect(find.text('Cash Register / Payment'), findsOneWidget);
      expect(find.text('Total Amount Due'), findsOneWidget);

      // Enter 500 in Cash Tendered field
      await tester.enterText(find.byType(TextField), '500');
      await tester.pumpAndSettle();

      // Change: ₱500 - ₱205 = ₱295
      expect(find.textContaining('295'), findsOneWidget);
      expect(find.text('Confirm Cash Receipt'), findsOneWidget);
    });
  });
}
