import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import 'package:orderacoffee/backend/services/paymongo_service.dart';
import 'package:orderacoffee/frontend/features/cart/cart_provider.dart';

void main() {
  group('PayMongo Integration & Webhook Architecture Tests', () {
    final paymongo = PayMongoService();

    const sampleDraft = OrderDraft(
      userId: 'user_123',
      userName: 'Juan Dela Cruz',
      userEmail: 'juan@cafego.ph',
      items: [
        OrderItem(
          itemId: 'cappuccino',
          name: 'Cappuccino',
          qty: 2,
          unitPrice: 140,
        ),
      ],
      type: OrderType.delivery,
      address: 'BGC High Street, Taguig',
      payment: PaymentMethod.gcash,
      subtotal: 280,
      deliveryFee: kStandardDeliveryFee,
      discount: 0,
    );

    test('buildCheckoutPayload formats centavos, delivery fee, and metadata', () {
      final payload = paymongo.buildCheckoutPayload(
        orderId: 'ORD-999',
        draft: sampleDraft,
      );
      final attrs =
          (payload['data'] as Map<String, dynamic>)['attributes']
              as Map<String, dynamic>;
      final lineItems = attrs['line_items'] as List<dynamic>;

      // 2x Cappuccino (14000 centavos) + Delivery Fee (4500 centavos)
      expect(lineItems.length, 2);
      expect(lineItems[0]['amount'], 14000);
      expect(lineItems[0]['quantity'], 2);
      expect(lineItems[1]['name'], 'Standard Delivery Fee');
      expect(lineItems[1]['amount'], 4500);

      expect(attrs['payment_method_types'], ['gcash']);
      expect(attrs['reference_number'], 'ORD-999');
      expect(attrs['metadata']['orderId'], 'ORD-999');
    });

    test('createCheckoutSession returns valid checkout session URL', () async {
      final session = await paymongo.createCheckoutSession(
        orderId: 'ORD-999',
        draft: sampleDraft,
      );
      expect(session.id, startsWith('cs_'));
      expect(session.checkoutUrl, contains('checkout.paymongo.com'));
      expect(session.referenceNumber, 'ORD-999');
    });

    test('verifyWebhookSignature validates HMAC-SHA256 signature and rejects tampering', () {
      const secret = 'whsec_test_secret_key';
      const rawBody =
          '{"data":{"id":"evt_1","attributes":{"type":"checkout_session.payment.paid"}}}';
      const timestamp = '1730000000';

      const signedPayload = '$timestamp.$rawBody';
      final digest = Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode(signedPayload))
          .toString();
      final header = 't=$timestamp,te=$digest,li=';

      expect(
        PayMongoService.verifyWebhookSignature(
          rawPayload: rawBody,
          signatureHeader: header,
          webhookSecret: secret,
        ),
        isTrue,
      );

      expect(
        PayMongoService.verifyWebhookSignature(
          rawPayload: rawBody,
          signatureHeader: 't=$timestamp,te=invalid_signature,li=',
          webhookSecret: secret,
        ),
        isFalse,
      );
    });

    test('parseWebhookEvent extracts orderId, paymentId, and paid status', () {
      final eventBody = {
        'data': {
          'id': 'evt_123',
          'attributes': {
            'type': 'checkout_session.payment.paid',
            'data': {
              'id': 'cs_abc123',
              'attributes': {
                'reference_number': 'ORD-777',
                'metadata': {'orderId': 'ORD-777'},
                'payments': [
                  {'id': 'pay_xyz987'}
                ],
              },
            },
          },
        },
      };

      final parsed = PayMongoService.parseWebhookEvent(eventBody);
      expect(parsed, isNotNull);
      expect(parsed!.eventType, 'checkout_session.payment.paid');
      expect(parsed.orderId, 'ORD-777');
      expect(parsed.checkoutSessionId, 'cs_abc123');
      expect(parsed.paymentId, 'pay_xyz987');
      expect(parsed.paymentStatus, PaymentStatus.paid);
    });
  });

  group('Geolocation & Live Order Map Routing Tests', () {
    test('kCafeBranches provides 4 branches with coordinates', () {
      expect(kCafeBranches.length, 4);
      final bgc = LocationService.findBranch('bgc');
      expect(bgc.name, contains('BGC'));
    });

    test('Distance, ETA, and route waypoint interpolation work accurately', () {
      const origin = LatLng(14.5505, 121.0514); // BGC
      const dest = LatLng(14.5568, 121.0235); // Makati

      final km = LocationService.computeDistanceKm(origin, dest);
      expect(km, greaterThan(2.0));
      expect(km, lessThan(5.0));

      final eta = LocationService.computeEtaMinutes(origin, dest);
      expect(eta, greaterThanOrEqualTo(5));

      final waypoints = LocationService.generateRouteWaypoints(origin, dest);
      expect(waypoints.length, 5);
      expect(waypoints.first, origin);
      expect(waypoints.last, dest);
    });
  });

  group('Cart Line Merging & Customization Equality Tests', () {
    const testItem = MenuItem(
      id: 'latte',
      name: 'Latte',
      category: 'Hot Coffee',
      description: 'Smooth espresso',
      basePrice: 150,
    );

    test('CartNotifier merges identical lines and separates distinct customizations', () {
      final notifier = CartNotifier();
      const customOat = CartCustomizations(
        size: SizeOption(label: 'Large', delta: 20),
        milk: MilkOption(label: 'Oat', delta: 25),
        sugar: '50%',
      );
      const customSoy = CartCustomizations(
        size: SizeOption(label: 'Large', delta: 20),
        milk: MilkOption(label: 'Soy', delta: 20),
        sugar: '50%',
      );

      notifier.addLine(testItem, customOat, 1);
      notifier.addLine(testItem, customOat, 2);
      expect(notifier.state.lines.length, 1);
      expect(notifier.state.lines.first.qty, 3);

      notifier.addLine(testItem, customSoy, 1);
      expect(notifier.state.lines.length, 2);
      expect(notifier.state.itemCount, 4);
    });
  });
}
