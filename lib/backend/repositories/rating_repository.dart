import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import '../models/order_rating.dart';

class RatingRepository {
  RatingRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get firestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Submit a rating for an order (validates 1..5 star bounds).
  Future<void> submitRating({
    required String orderId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    if (rating < 1.0 || rating > 5.0) {
      throw const ValidationFailure('Rating must be between 1 and 5 stars.');
    }
    final fs = firestore;
    if (fs == null) {
      throw const ValidationFailure('Firestore is not initialized');
    }

    await fs
        .collection('orders')
        .doc(orderId)
        .collection('ratings')
        .doc(userId)
        .set({
      'orderId': orderId,
      'userId': userId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if user has already rated this order
  Future<bool> hasRated({
    required String orderId,
    required String userId,
  }) async {
    final fs = firestore;
    if (fs == null) return false;
    final doc = await fs
        .collection('orders')
        .doc(orderId)
        .collection('ratings')
        .doc(userId)
        .get();
    return doc.exists;
  }

  /// Get a user's rating for an order
  Future<OrderRating?> getRating({
    required String orderId,
    required String userId,
  }) async {
    final fs = firestore;
    if (fs == null) return null;
    final doc = await fs
        .collection('orders')
        .doc(orderId)
        .collection('ratings')
        .doc(userId)
        .get();

    if (!doc.exists) return null;

    return OrderRating.fromFirestore(doc);
  }

  /// Get all ratings for an order
  Future<List<OrderRating>> getOrderRatings(String orderId) async {
    final fs = firestore;
    if (fs == null) return const [];
    final snapshot = await fs
        .collection('orders')
        .doc(orderId)
        .collection('ratings')
        .get();

    return snapshot.docs
        .map((doc) => OrderRating.fromFirestore(doc))
        .toList();
  }

  /// Get average rating for an order
  Future<double> getAverageRating(String orderId) async {
    final ratings = await getOrderRatings(orderId);
    if (ratings.isEmpty) return 0.0;

    final sum = ratings.fold<double>(0, (sum, rating) => sum + rating.rating);
    return sum / ratings.length;
  }
}
