import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/order.dart';
import 'package:orderacoffee/data/repositories/loyalty_repository.dart';
import 'package:orderacoffee/data/repositories/reports_repository.dart';

void main() {
  group('LoyaltyRepository (L1 - L3)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LoyaltyRepository loyaltyRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      loyaltyRepo = LoyaltyRepository(firestore: fakeFirestore);
    });

    test('L1 & L3: earnStamp increments stamps count and watchStamps streams it', () async {
      await fakeFirestore.collection('users').doc('stamp_user').set({
        'stamps': 2,
      });

      await loyaltyRepo.earnStamp('stamp_user');
      final currentStamps = await loyaltyRepo.watchStamps('stamp_user').first;
      expect(currentStamps, 3);
    });

    test('L2: redeemStamps succeeds when stamps >= 8, deducts 8 and returns reward code', () async {
      await fakeFirestore.collection('users').doc('loyal_user').set({
        'stamps': 10,
      });

      final code = await loyaltyRepo.redeemStamps('loyal_user');
      expect(code, startsWith('REWARD-'));

      final doc = await fakeFirestore.collection('users').doc('loyal_user').get();
      expect(doc.data()?['stamps'], 2);
    });

    test('L2: redeemStamps throws ValidationFailure when stamps < 8', () async {
      await fakeFirestore.collection('users').doc('poor_user').set({
        'stamps': 7,
      });

      expect(
        () => loyaltyRepo.redeemStamps('poor_user'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('ReportsRepository (R1 - R3)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ReportsRepository reportsRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      reportsRepo = ReportsRepository(firestore: fakeFirestore);
    });

    test('R1: watchDailySummary streams sales summary for a date', () async {
      await fakeFirestore.collection('sales').doc('2026-10-28').set({
        'orderCount': 42,
        'revenue': 8400.0,
      });

      final summary = await reportsRepo.watchDailySummary('2026-10-28').first;
      expect(summary?.date, '2026-10-28');
      expect(summary?.orderCount, 42);
      expect(summary?.revenue, 8400.0);
    });

    test('R2: getRangeSummary returns summaries in date range', () async {
      await fakeFirestore.collection('sales').doc('2026-10-26').set({'orderCount': 10, 'revenue': 1000.0});
      await fakeFirestore.collection('sales').doc('2026-10-27').set({'orderCount': 20, 'revenue': 2000.0});
      await fakeFirestore.collection('sales').doc('2026-10-28').set({'orderCount': 30, 'revenue': 3000.0});

      final summaries = await reportsRepo.getRangeSummary(
        fromDate: '2026-10-26',
        toDate: '2026-10-27',
      );

      expect(summaries.length, 2);
      expect(summaries.map((s) => s.date).toList(), equals(['2026-10-26', '2026-10-27']));
    });

    test('R3: getTopItems aggregates quantity and revenue from completed orders', () async {
      final from = DateTime(2026, 10, 1);
      final to = DateTime(2026, 10, 31);

      // Add completed order
      await fakeFirestore.collection('orders').add({
        'status': OrderStatus.completed.name,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 15)),
        'items': [
          {'itemId': 'item_a', 'name': 'Spanish Latte', 'qty': 3, 'unitPrice': 120.0, 'total': 360.0},
          {'itemId': 'item_b', 'name': 'Croissant', 'qty': 1, 'unitPrice': 80.0, 'total': 80.0},
        ],
      });

      // Add another completed order
      await fakeFirestore.collection('orders').add({
        'status': OrderStatus.completed.name,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 16)),
        'items': [
          {'itemId': 'item_a', 'name': 'Spanish Latte', 'qty': 2, 'unitPrice': 120.0, 'total': 240.0},
        ],
      });

      // Add non-completed order (should be ignored)
      await fakeFirestore.collection('orders').add({
        'status': OrderStatus.preparing.name,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 16)),
        'items': [
          {'itemId': 'item_b', 'name': 'Croissant', 'qty': 5, 'unitPrice': 80.0, 'total': 400.0},
        ],
      });

      final topItems = await reportsRepo.getTopItems(from: from, to: to);
      expect(topItems.length, 2);
      expect(topItems.first['itemId'], 'item_a');
      expect(topItems.first['qty'], 5); // 3 + 2
      expect(topItems.first['revenue'], 600.0); // 360 + 240
    });
  });
}
