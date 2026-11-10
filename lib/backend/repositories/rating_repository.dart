import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_rating.dart';

class RatingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a rating for an order
  Future<void> submitRating({
    required String orderId,
    required String userId,
    required double rating,
    String? review,
  }) async {
    try {
      await _firestore
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
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user has already rated this order
  Future<bool> hasRated({
    required String orderId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('ratings')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      rethrow;
    }
  }

  /// Get a user's rating for an order
  Future<OrderRating?> getRating({
    required String orderId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('ratings')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return OrderRating.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all ratings for an order
  Future<List<OrderRating>> getOrderRatings(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('ratings')
          .get();

      return snapshot.docs
          .map((doc) => OrderRating.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get average rating for an order
  Future<double> getAverageRating(String orderId) async {
    try {
      final ratings = await getOrderRatings(orderId);
      if (ratings.isEmpty) return 0.0;

      final sum = ratings.fold<double>(0, (sum, rating) => sum + rating.rating);
      return sum / ratings.length;
    } catch (e) {
      rethrow;
    }
  }
}
