import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/seed/seed_menu_data.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/features/menu/item_detail_sheet.dart';
import 'package:orderacoffee/frontend/features/orders/order_tracking_screen.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/widgets/item_card.dart';
import 'package:orderacoffee/frontend/widgets/scooter_delivery_graphic.dart';

void main() {
  group('UI Redesign Visual References Verification', () {
    test('peso() formats amounts as whole Philippine pesos with clean spacing', () {
      expect(peso(140), '₱ 140');
      expect(peso(165.0), '₱ 165');
      expect(peso(1250), '₱ 1,250');
      expect(peso(3.45), '₱ 3'); // Whole peso amount as requested
    });

    test('Catalog contains the 5 reference drinks from Picture 1 at top of Hot Coffee', () {
      final hotCoffees = kDefaultMenuItems.where((e) => e.category == 'Hot Coffee').toList();
      expect(hotCoffees[0].name, 'Cappuccino');
      expect(hotCoffees[0].description, 'Perfect balance of espresso, steamed milk and foam.');
      expect(hotCoffees[1].name, 'Latte');
      expect(hotCoffees[1].description, 'Smooth espresso with steamed milk.');
      expect(hotCoffees[2].name, 'Mocha');
      expect(hotCoffees[2].description, 'Chocolate, espresso and steamed milk.');
      expect(hotCoffees[3].name, 'Americano');
      expect(hotCoffees[3].description, 'Espresso diluted with hot water.');
      expect(hotCoffees[4].name, 'Flat White');
      expect(hotCoffees[4].description, 'Rich espresso with steamed milk.');
    });

    testWidgets('ItemCard (Picture 1) renders title, description, whole peso price, and brown + button', (tester) async {
      final item = kDefaultMenuItems.firstWhere((e) => e.name == 'Cappuccino');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemCard(item: item),
          ),
        ),
      );

      expect(find.text('Cappuccino'), findsOneWidget);
      expect(find.text('Perfect balance of espresso, steamed milk and foam.'), findsOneWidget);
      expect(find.text('₱ 140'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('ItemDetailSheet (Picture 2) renders Customize header, Size pills, Milk pills, Shots, and Extra checkboxes', (tester) async {
      final item = kDefaultMenuItems.firstWhere((e) => e.name == 'Cappuccino');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ItemDetailSheet(item: item),
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Customize'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Verify item title and price
      expect(find.text('Cappuccino'), findsOneWidget);
      expect(find.text('₱ 140'), findsWidgets);

      // Verify Sections
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Oat'), findsOneWidget);
      expect(find.text('Almond'), findsOneWidget);
      expect(find.text('Soy'), findsOneWidget);

      expect(find.text('Shots'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // shots and quantity
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      expect(find.text('Extra'), findsOneWidget);
      expect(find.text('Extra shot'), findsOneWidget);
      expect(find.text('Vanilla syrup'), findsOneWidget);

      // Verify Bottom bar
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('OrderTrackingScreen (Picture 3) renders ETA, courier scooter graphic, 4-step stepper, and Order Details', (tester) async {
      const mockOrder = Order(
        id: 'mock-bb2456',
        userId: 'u1',
        userName: 'Customer',
        total: 290,
        type: OrderType.delivery,
        payment: PaymentMethod.counter,
        status: OrderStatus.ready, // "On the way"
        items: [
          OrderItem(
            itemId: 'cappuccino',
            name: 'Cappuccino',
            qty: 1,
            unitPrice: 140,
          ),
          OrderItem(
            itemId: 'mocha',
            name: 'Mocha',
            qty: 1,
            unitPrice: 150,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderStreamProvider('mock-bb2456').overrideWith(
              (ref) => Stream.value(mockOrder),
            ),
          ],
          child: const MaterialApp(
            home: OrderTrackingScreen(orderId: 'mock-bb2456'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Header and Order ID
      expect(find.text('Order Tracking'), findsOneWidget);
      expect(find.text('Order #BB2456'), findsOneWidget);

      // Verify Estimated Delivery
      expect(find.text('Estimated Delivery'), findsOneWidget);
      expect(find.text('15–20 mins'), findsOneWidget);
      expect(find.text('Your order is on the way!'), findsOneWidget);

      // Verify Courier Graphic
      expect(find.byType(ScooterDeliveryGraphic), findsOneWidget);

      // Verify 4-Stage Horizontal Status Stepper
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);

      // Verify Order Details Card
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('1 x Cappuccino'), findsOneWidget);
      expect(find.text('1 x Mocha'), findsOneWidget);
      expect(find.text('₱ 140'), findsOneWidget);
      expect(find.text('₱ 150'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₱ 290'), findsOneWidget);
    });
  });
}
