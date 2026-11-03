import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/frontend/features/cart/cart_provider.dart';
import 'package:orderacoffee/frontend/features/cart/cart_screen.dart';

void main() {
  group('CartScreen Clean Typography Tests', () {
    testWidgets('renders cart line with clean quantity formatting without Mojibake', (tester) async {
      const testItem = MenuItem(
        id: 'latte',
        name: 'Spanish Latte',
        category: 'Hot Coffee',
        description: 'Classy latte',
        basePrice: 140.0,
      );

      const cust = CartCustomizations(
        size: SizeOption(label: 'Medium', delta: 0),
        milk: MilkOption(label: 'Whole', delta: 0),
        sugar: '50%',
        ice: 'Regular',
      );

      final container = ProviderContainer();
      container.read(cartProvider.notifier).addLine(testItem, cust, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CartScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify readable item title
      expect(find.text('1x Spanish Latte'), findsOneWidget);
      // Verify bullet separator
      expect(find.text('Medium • Whole • 50% sugar • Regular'), findsOneWidget);

      // Verify no corrupted characters anywhere on the screen
      expect(find.textContaining('Ã'), findsNothing);
      expect(find.textContaining('Â'), findsNothing);
    });
  });
}
