import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/backend/models/order_rating.dart';
import 'package:orderacoffee/backend/repositories/rating_repository.dart';
import 'package:orderacoffee/core/errors/failures.dart';

void main() {
  group('RatingRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late RatingRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = RatingRepository(firestore: fakeFirestore);
    });

    test('submitRating, hasRated, and getRating persist and retrieve rating', () async {
      expect(
        await repository.hasRated(orderId: 'ORD-1', userId: 'user-1'),
        isFalse,
      );

      await repository.submitRating(
        orderId: 'ORD-1',
        userId: 'user-1',
        rating: 5.0,
        review: 'Perfect Spanish Latte!',
      );

      expect(
        await repository.hasRated(orderId: 'ORD-1', userId: 'user-1'),
        isTrue,
      );

      final fetched = await repository.getRating(
        orderId: 'ORD-1',
        userId: 'user-1',
      );
      expect(fetched, isNotNull);
      expect(fetched!.orderId, 'ORD-1');
      expect(fetched.userId, 'user-1');
      expect(fetched.rating, 5.0);
      expect(fetched.review, 'Perfect Spanish Latte!');
    });

    test('submitRating rejects ratings below 1 or above 5', () async {
      await expectLater(
        () => repository.submitRating(
          orderId: 'ORD-1',
          userId: 'user-1',
          rating: 0.0,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      await expectLater(
        () => repository.submitRating(
          orderId: 'ORD-1',
          userId: 'user-1',
          rating: 5.5,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('getOrderRatings and getAverageRating calculate deterministic average', () async {
      await repository.submitRating(
        orderId: 'ORD-AVG',
        userId: 'user-1',
        rating: 5.0,
      );
      await repository.submitRating(
        orderId: 'ORD-AVG',
        userId: 'user-2',
        rating: 3.0,
      );

      final ratings = await repository.getOrderRatings('ORD-AVG');
      expect(ratings.length, 2);

      final avg = await repository.getAverageRating('ORD-AVG');
      expect(avg, 4.0);
    });

    test('getAverageRating returns 0.0 when order has no ratings', () async {
      expect(await repository.getAverageRating('ORD-EMPTY'), 0.0);
    });

    test('OrderRating.fromFirestore handles null createdAt safely', () async {
      await fakeFirestore
          .collection('orders')
          .doc('ORD-NULL-TS')
          .collection('ratings')
          .doc('user-1')
          .set({
        'orderId': 'ORD-NULL-TS',
        'userId': 'user-1',
        'rating': 4,
        'review': null,
        'createdAt': null,
      });

      final doc = await fakeFirestore
          .collection('orders')
          .doc('ORD-NULL-TS')
          .collection('ratings')
          .doc('user-1')
          .get();

      final parsed = OrderRating.fromFirestore(doc);
      expect(parsed.rating, 4.0);
      expect(parsed.orderId, 'ORD-NULL-TS');
      expect(parsed.createdAt, isA<DateTime>());

      // Verify Timestamp path works identically
      await fakeFirestore
          .collection('orders')
          .doc('ORD-TS')
          .collection('ratings')
          .doc('user-1')
          .set({
        'orderId': 'ORD-TS',
        'userId': 'user-1',
        'rating': 5,
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 16, 10, 0)),
      });
      final tsDoc = await fakeFirestore
          .collection('orders')
          .doc('ORD-TS')
          .collection('ratings')
          .doc('user-1')
          .get();
      expect(
        OrderRating.fromFirestore(tsDoc).createdAt,
        DateTime(2026, 11, 16, 10, 0),
      );
    });
  });
}
