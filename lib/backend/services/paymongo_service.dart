import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';

/// Configuration for PayMongo API & Webhook integration.
///
/// Inject keys at build/run time via `--dart-define`:
///   flutter run \
///     --dart-define=PAYMONGO_PUBLIC_KEY=pk_test_xxx \
///     --dart-define=PAYMONGO_SECRET_KEY=sk_test_xxx \
///     --dart-define=PAYMONGO_WEBHOOK_SECRET=whsk_xxx \
///     --dart-define=PAYMONGO_SUCCESS_URL=https://cafego.ph/payment/success \
///     --dart-define=PAYMONGO_CANCEL_URL=https://cafego.ph/payment/cancel
class PayMongoConfig {
  PayMongoConfig._();

  static const String publicKey = String.fromEnvironment(
    'PAYMONGO_PUBLIC_KEY',
    defaultValue: '',
  );

  static const String secretKey = String.fromEnvironment(
    'PAYMONGO_SECRET_KEY',
    defaultValue: '',
  );

  static const String webhookSecret = String.fromEnvironment(
    'PAYMONGO_WEBHOOK_SECRET',
    defaultValue: '',
  );

  static const String checkoutSuccessUrl = String.fromEnvironment(
    'PAYMONGO_SUCCESS_URL',
    defaultValue: 'https://cafego.ph/orders/success',
  );

  static const String checkoutCancelUrl = String.fromEnvironment(
    'PAYMONGO_CANCEL_URL',
    defaultValue: 'https://cafego.ph/orders/cancel',
  );

  static const String apiBaseUrl = 'https://api.paymongo.com/v1';

  static bool get isConfigured => secretKey.isNotEmpty;
}

class PayMongoCheckoutSession {
  const PayMongoCheckoutSession({
    required this.id,
    required this.checkoutUrl,
    required this.referenceNumber,
    required this.paymentMethodType,
    required this.amountCentavos,
    this.isSimulated = false,
  });

  final String id;
  final String checkoutUrl;
  final String referenceNumber;
  final String paymentMethodType;
  final int amountCentavos;
  final bool isSimulated;
}

class PayMongoWebhookEvent {
  const PayMongoWebhookEvent({
    required this.eventId,
    required this.eventType,
    required this.orderId,
    required this.paymentStatus,
    this.paymentId,
    this.checkoutSessionId,
  });

  final String eventId;
  final String eventType;
  final String orderId;
  final PaymentStatus paymentStatus;
  final String? paymentId;
  final String? checkoutSessionId;
}

/// Service for creating PayMongo Checkout Sessions and processing PayMongo Webhooks.
///
/// ### Webhook API Contract for Your Backend
/// Configure a PayMongo webhook listening to:
/// - `checkout_session.payment.paid`
/// - `payment.paid`
/// - `payment.failed`
///
/// When your webhook endpoint receives an event:
/// 1. Verify the `Paymongo-Signature` header using [verifyWebhookSignature].
/// 2. Parse the event using [parseWebhookEvent] to extract `orderId` (`reference_number` or `metadata.orderId`).
/// 3. Update `orders/{orderId}` in Cloud Firestore:
///    ```json
///    {
///      "paymentStatus": "paid",
///      "paymongoPaymentId": "<paymentId>",
///      "updatedAt": "<ServerTimestamp>"
///    }
///    ```
/// The CafeGO app watches `orders/{orderId}` in real time and automatically transitions
/// the order payment badge to `PAID`.
class PayMongoService {
  PayMongoService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Builds the exact PayMongo `/v1/checkout_sessions` request payload.
  Map<String, dynamic> buildCheckoutPayload({
    required String orderId,
    required OrderDraft draft,
  }) {
    final totalCentavos = (draft.total * 100).round();
    final lineItems = <Map<String, dynamic>>[];

    if (draft.discount > 0 && draft.items.isNotEmpty) {
      // When a loyalty discount is applied, submit a consolidated order summary line
      // plus delivery fee so line items strictly equal the charged total in centavos.
      final discountedSubtotalCentavos =
          ((draft.subtotal - draft.discount).clamp(0.0, double.infinity) * 100)
              .round();
      if (discountedSubtotalCentavos > 0) {
        lineItems.add({
          'name':
              'CafeGO Order ($orderId) - ${draft.items.length} item(s) (Loyalty Discount Applied)',
          'quantity': 1,
          'amount': discountedSubtotalCentavos,
          'currency': 'PHP',
        });
      }
    } else {
      for (final item in draft.items) {
        lineItems.add({
          'name': item.name,
          'quantity': item.qty,
          'amount': (item.unitPrice * 100).round(),
          'currency': 'PHP',
          if (item.customizationSummary.isNotEmpty)
            'description': item.customizationSummary,
        });
      }
    }

    if (draft.deliveryFee > 0) {
      lineItems.add({
        'name': 'Standard Delivery Fee',
        'quantity': 1,
        'amount': (draft.deliveryFee * 100).round(),
        'currency': 'PHP',
      });
    }

    // Fallback if total is 0 or lineItems is empty
    if (lineItems.isEmpty && totalCentavos > 0) {
      lineItems.add({
        'name': 'CafeGO Order $orderId',
        'quantity': 1,
        'amount': totalCentavos,
        'currency': 'PHP',
      });
    }

    return {
      'data': {
        'attributes': {
          'send_email_receipt': draft.userEmail != null && draft.userEmail!.isNotEmpty,
          'show_description': true,
          'show_line_items': true,
          'description': 'CafeGO Order $orderId (${draft.type.value})',
          'reference_number': orderId,
          'payment_method_types': [draft.payment.paymongoMethodType],
          'line_items': lineItems,
          'success_url': '${PayMongoConfig.checkoutSuccessUrl}?orderId=$orderId',
          'cancel_url': '${PayMongoConfig.checkoutCancelUrl}?orderId=$orderId',
          'billing': {
            'name': draft.userName,
            if (draft.userEmail != null && draft.userEmail!.isNotEmpty)
              'email': draft.userEmail,
          },
          'metadata': {
            'orderId': orderId,
            'userId': draft.userId,
            'userName': draft.userName,
            'orderType': draft.type.value,
          },
        },
      },
    };
  }

  /// Creates a PayMongo Checkout Session for `gcash`, `maya`, or `card`.
  /// If `PAYMONGO_SECRET_KEY` is provided, calls PayMongo REST API directly;
  /// otherwise returns a sandbox session ready for webhook or in-app authorization.
  Future<PayMongoCheckoutSession> createCheckoutSession({
    required String orderId,
    required OrderDraft draft,
  }) async {
    final payload = buildCheckoutPayload(orderId: orderId, draft: draft);
    final amountCentavos = (draft.total * 100).round();
    final methodType = draft.payment.paymongoMethodType;

    if (PayMongoConfig.isConfigured) {
      try {
        final basicAuth =
            'Basic ${base64Encode(utf8.encode('${PayMongoConfig.secretKey}:'))}';
        final response = await _httpClient.post(
          Uri.parse('${PayMongoConfig.apiBaseUrl}/checkout_sessions'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': basicAuth,
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final data = decoded['data'] as Map<String, dynamic>? ?? {};
          final attrs = data['attributes'] as Map<String, dynamic>? ?? {};
          return PayMongoCheckoutSession(
            id: data['id'] as String? ?? 'cs_$orderId',
            checkoutUrl: attrs['checkout_url'] as String? ?? '',
            referenceNumber: orderId,
            paymentMethodType: methodType,
            amountCentavos: amountCentavos,
            isSimulated: false,
          );
        } else {
          debugPrint(
              '[PayMongo] API returned ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('[PayMongo] Network error creating checkout session: $e');
      }
    }

    final cleanId = orderId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final sessionId = 'cs_test_${cleanId}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    return PayMongoCheckoutSession(
      id: sessionId,
      checkoutUrl: 'https://checkout.paymongo.com/$sessionId?orderId=$orderId',
      referenceNumber: orderId,
      paymentMethodType: methodType,
      amountCentavos: amountCentavos,
      isSimulated: true,
    );
  }

  /// Verifies the `Paymongo-Signature` HTTP header using HMAC-SHA256.
  /// Header format: `t=1614556800,te=test_sig_hex,li=live_sig_hex`
  static bool verifyWebhookSignature({
    required String rawPayload,
    required String signatureHeader,
    required String webhookSecret,
    bool isLiveMode = false,
  }) {
    if (signatureHeader.isEmpty || webhookSecret.isEmpty) return false;

    String? timestamp;
    String? testSig;
    String? liveSig;

    for (final part in signatureHeader.split(',')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      if (kv[0] == 't') timestamp = kv[1];
      if (kv[0] == 'te') testSig = kv[1];
      if (kv[0] == 'li') liveSig = kv[1];
    }

    if (timestamp == null) return false;
    final expectedSig = isLiveMode ? liveSig : (testSig ?? liveSig);
    if (expectedSig == null || expectedSig.isEmpty) return false;

    final signedPayload = '$timestamp.$rawPayload';
    final hmac = Hmac(sha256, utf8.encode(webhookSecret));
    final computed = hmac.convert(utf8.encode(signedPayload)).toString();

    return computed.toLowerCase() == expectedSig.toLowerCase();
  }

  /// Parses a PayMongo Webhook JSON body (`checkout_session.payment.paid`, `payment.paid`, `payment.failed`)
  /// into a normalized [PayMongoWebhookEvent] containing the target `orderId` and [PaymentStatus].
  static PayMongoWebhookEvent? parseWebhookEvent(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final eventId = data['id'] as String? ?? '';
    final attributes = data['attributes'] as Map<String, dynamic>? ?? {};
    final eventType = attributes['type'] as String? ?? '';
    final resource = attributes['data'] as Map<String, dynamic>? ?? {};
    final resourceId = resource['id'] as String?;
    final resourceAttrs =
        resource['attributes'] as Map<String, dynamic>? ?? {};

    final metadata =
        resourceAttrs['metadata'] as Map<String, dynamic>? ?? {};
    final referenceNumber = resourceAttrs['reference_number'] as String? ??
        resourceAttrs['external_reference_number'] as String?;
    final orderId =
        (metadata['orderId'] as String?) ?? referenceNumber ?? '';

    if (orderId.isEmpty) return null;

    PaymentStatus status = PaymentStatus.pending;
    if (eventType == 'checkout_session.payment.paid' ||
        eventType == 'payment.paid') {
      status = PaymentStatus.paid;
    } else if (eventType == 'payment.failed') {
      status = PaymentStatus.failed;
    } else if (eventType.contains('refund')) {
      status = PaymentStatus.refunded;
    }

    String? paymentId;
    final payments = resourceAttrs['payments'] as List<dynamic>?;
    if (payments != null && payments.isNotEmpty) {
      final firstPayment = payments.first;
      if (firstPayment is Map) {
        paymentId = firstPayment['id'] as String?;
      }
    }
    paymentId ??= resourceId;

    return PayMongoWebhookEvent(
      eventId: eventId,
      eventType: eventType,
      orderId: orderId,
      paymentStatus: status,
      paymentId: paymentId,
      checkoutSessionId:
          eventType.startsWith('checkout_session') ? resourceId : null,
    );
  }
}
