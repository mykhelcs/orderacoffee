import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/driver/driver_screen.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(UserProfile profile) : super(AuthState(profile: profile));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DriverScreen Delivery Cockpit Widget Tests', () {
    const testDriver = UserProfile(
      uid: 'driver_test_uid',
      name: 'Rider Juan',
      email: 'driver@cafego.ph',
      phone: '+63 917 123 4567',
      role: 'driver',
      vehicleType: 'motorcycle',
      vehicleNumber: 'XYZ-7890',
    );

    final readyOrders = [
      Order(
        id: 'ORD-DELIVERY-1',
        userId: 'cust_9',
        userName: 'Pia Wurtzbach',
        items: const [
          OrderItem(
            itemId: 'item_cold_brew',
            name: 'Signature Cold Brew',
            unitPrice: 160.0,
            qty: 2,
          ),
        ],
        subtotal: 320.0,
        deliveryFee: 45.0,
        total: 365.0,
        type: OrderType.delivery,
        address: 'BGC High Street Unit 401',
        status: OrderStatus.ready,
        payment: PaymentMethod.cash,
        createdAt: DateTime.now(),
      ),
    ];

    Widget createDriverTestWidget({List<Order>? orders}) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testDriver)),
          allOrdersStreamProvider.overrideWith((ref) => Stream.value(orders ?? readyOrders)),
        ],
        child: const MaterialApp(
          home: DriverScreen(),
        ),
      );
    }

    testWidgets('Renders Driver Header, Vehicle badge, Online switch, and Available Orders Pool', (tester) async {
      await tester.pumpWidget(createDriverTestWidget());
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('DRIVER WORKSPACE'), findsOneWidget);
      expect(find.text('Rider Juan'), findsOneWidget);
      expect(find.textContaining('Motorcycle • ABC-1234'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);

      // Available Orders Pool
      expect(find.text('Available Orders Pool (1)'), findsOneWidget);
      expect(find.text('Pia Wurtzbach'), findsOneWidget);
      expect(find.text('+₱45 Fee'), findsOneWidget);
      expect(find.text('Accept Delivery'), findsOneWidget);
    });

    testWidgets('Tapping Accept Delivery switches to Active Delivery in progress', (tester) async {
      await tester.pumpWidget(createDriverTestWidget());
      await tester.pumpAndSettle();

      // Tap Accept Delivery
      await tester.tap(find.text('Accept Delivery'));
      await tester.pumpAndSettle();

      // Active view verification
      expect(find.text('ACTIVE DELIVERY IN PROGRESS'), findsOneWidget);
      expect(find.textContaining('BGC High Street Unit 401'), findsWidgets);
      expect(find.text('Call Customer'), findsOneWidget);
      expect(find.text('Advance GPS'), findsOneWidget);
      expect(find.textContaining('Complete & Collect'), findsOneWidget);
    });
  });
}
