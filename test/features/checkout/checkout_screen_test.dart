import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/repositories/order_repository.dart';
import 'package:orderacoffee/frontend/features/checkout/checkout_screen.dart';

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
  });
}
