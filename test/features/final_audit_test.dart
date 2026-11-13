import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'package:orderacoffee/backend/config/admin_config.dart';
import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/auth_repository.dart';
import 'package:orderacoffee/backend/repositories/order_repository.dart';
import 'package:orderacoffee/backend/services/paymongo_service.dart';
import 'package:orderacoffee/backend/services/security.dart';
import 'package:orderacoffee/backend/services/smtp_service.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/cart/cart_provider.dart';
import 'package:orderacoffee/frontend/features/driver/driver_screen.dart';
import 'package:orderacoffee/frontend/features/orders/order_tracking_screen.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/features/staff/staff_screen.dart';

class _OkSmtpService extends SmtpService {
  @override
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
  }) async {
    return true;
  }
}

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier(UserProfile profile) : super(AuthState(profile: profile));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingCancelOrderRepository extends OrderRepository {
  _FailingCancelOrderRepository(this._order);
  final Order _order;

  @override
  Stream<Order?> watchOrder(String id) => Stream.value(_order);

  @override
  Future<void> cancelOrder(String id) async {
    throw const OrderStateFailure(
      'Cannot cancel order in "preparing" status. Cancellation is only allowed when "received".',
    );
  }
}

class _FailingAdvanceOrderRepository extends OrderRepository {
  _FailingAdvanceOrderRepository(this._orders);
  final List<Order> _orders;

  @override
  Stream<List<Order>> liveQueue() => Stream.value(_orders);

  @override
  Future<void> advanceStatus(String id, OrderStatus next) async {
    throw const PermissionFailure('Insufficient permissions');
  }
}

void main() {
  group('Final Pentest Security Checks', () {
    test('OTP verification stores SHA-256 hash instead of plaintext and verifies deterministically', () async {
      final fakeFs = FakeFirebaseFirestore();
      final repo = AuthRepository(
        auth: MockFirebaseAuth(),
        firestore: fakeFs,
        smtpService: _OkSmtpService(),
      );

      final code = await repo.sendEmailVerificationCode('Alice@Example.com');
      final doc = await fakeFs
          .collection('email_verifications')
          .doc('alice@example.com')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?.containsKey('code'), isFalse);
      expect(
        doc.data()?['codeHash'],
        equals(hashPassword(code, salt: 'alice@example.com')),
      );

      expect(
        await repo.verifyEmailCode(email: 'alice@example.com', code: code),
        isTrue,
      );
    });

    test('AdminConfig rejects lookalike admin domains', () {
      expect(AdminConfig.isAdminEmail('admin@cafego.ph'), isTrue);
      expect(AdminConfig.isAdminEmail('admin@evil.com'), isFalse);
      expect(AdminConfig.isAdminEmail('superadmin@cafego.ph'), isFalse);
    });

    test('SmtpService enforces TLS validation (allowInsecure == false) on custom SMTP', () async {
      SmtpServer? capturedServer;
      final service = SmtpService(
        username: 'ops@cafego.ph',
        password: 'app-password',
        sendFunction: (Message msg, SmtpServer server) async {
          capturedServer = server;
          return SendReport(msg, DateTime.now(), DateTime.now(), DateTime.now());
        },
      );

      // Force non-gmail fallback path by using custom SmtpServer check via reflection-free inspection:
      // Note: Default host is smtp.gmail.com; test verifies fallback SSL server does not allow insecure TLS.
      await service.sendOtpEmail(recipientEmail: 'user@example.com', otpCode: '123456');
      expect(capturedServer, isNotNull);
      expect(capturedServer!.allowInsecure, isFalse);
    });

    test('PayMongo checkout session referenceNumber matches Firestore order ID', () async {
      final fakeFs = FakeFirebaseFirestore();
      final repo = OrderRepository(firestore: fakeFs);
      final notifier = OrdersNotifier(repo, PayMongoService());

      const draft = OrderDraft(
        userId: 'cust-1',
        userName: 'Customer One',
        items: [
          OrderItem(
            itemId: 'latte',
            name: 'Latte',
            qty: 1,
            unitPrice: 150.0,
          ),
        ],
        type: OrderType.pickup,
        payment: PaymentMethod.gcash,
        subtotal: 150.0,
      );

      final createdId = await notifier.placeOrder(draft);
      final session = notifier.state.lastPaymongoSession;
      expect(session, isNotNull);
      expect(session!.referenceNumber, equals(createdId));

      final storedDoc = await fakeFs.collection('orders').doc(createdId).get();
      expect(storedDoc.exists, isTrue);
      expect(storedDoc.data()?['paymongoCheckoutId'], equals(session.id));
    });
  });

  group('Final QA Functional Checks', () {
    test('CartNotifier rejects zero or negative quantities', () {
      final notifier = CartNotifier();
      const item = MenuItem(
        id: 'espresso',
        name: 'Espresso',
        category: 'Hot Coffee',
        description: 'Rich shot',
        basePrice: 120.0,
      );

      notifier.addLine(item, const CartCustomizations(), 0);
      notifier.addLine(item, const CartCustomizations(), -2);
      expect(notifier.state.lines, isEmpty);
      expect(notifier.state.itemCount, 0);
    });

    testWidgets('DriverScreen prevents completing an order while still preparing', (tester) async {
      const driver = UserProfile(
        uid: 'drv-1',
        name: 'Driver Test',
        email: 'driver@cafego.ph',
        phone: '+63 917 555 0101',
        role: 'driver',
      );
      final preparingOrder = Order(
        id: 'ORD-PREP-1',
        userId: 'cust-1',
        userName: 'Anna Reyes',
        items: const [
          OrderItem(itemId: 'latte', name: 'Latte', qty: 1, unitPrice: 150),
        ],
        total: 195,
        deliveryFee: 45,
        type: OrderType.delivery,
        address: 'Makati Ave',
        payment: PaymentMethod.cash,
        status: OrderStatus.preparing,
        driverId: 'drv-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _FakeAuthNotifier(driver)),
            allOrdersStreamProvider.overrideWith((ref) => Stream.value([preparingOrder])),
          ],
          child: const MaterialApp(home: DriverScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for Kitchen to mark Ready'), findsOneWidget);
      expect(find.textContaining('Complete & Collect'), findsNothing);
      expect(find.text('Complete Delivery'), findsNothing);
    });

    testWidgets('OrderTrackingScreen handles OrderStateFailure on cancel gracefully', (tester) async {
      final receivedOrder = Order(
        id: 'ORD-TRACK-1',
        userId: 'cust-1',
        userName: 'Anna Reyes',
        items: const [
          OrderItem(itemId: 'latte', name: 'Latte', qty: 1, unitPrice: 150),
        ],
        total: 150,
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
        status: OrderStatus.received,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(
              _FailingCancelOrderRepository(receivedOrder),
            ),
          ],
          child: const MaterialApp(
            home: OrderTrackingScreen(orderId: 'ORD-TRACK-1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cancelFinder = find.text('Cancel Order');
      await tester.ensureVisible(cancelFinder);
      await tester.tap(cancelFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Cannot cancel order'), findsOneWidget);
    });

    testWidgets('StaffScreen handles advanceStatus failure gracefully with SnackBar', (tester) async {
      final order = Order(
        id: 'ORD-STAFF-1',
        userId: 'cust-1',
        userName: 'Marco Polo',
        items: const [
          OrderItem(itemId: 'latte', name: 'Latte', qty: 1, unitPrice: 150),
        ],
        total: 150,
        type: OrderType.pickup,
        payment: PaymentMethod.counter,
        status: OrderStatus.received,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderRepositoryProvider.overrideWithValue(
              _FailingAdvanceOrderRepository([order]),
            ),
          ],
          child: const MaterialApp(home: StaffScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Preparing'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Insufficient permissions'), findsOneWidget);
    });
  });
}
