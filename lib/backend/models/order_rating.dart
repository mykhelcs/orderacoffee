import 'package:cloud_firestore/cloud_firestore.dart';

class OrderRating {
  final String id;
  final String orderId;
  final String userId;
  final double rating; // 1-5 stars
  final String? review;
  final DateTime createdAt;

  OrderRating({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.rating,
    this.review,
    required this.createdAt,
  });

  factory OrderRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderRating(
      id: doc.id,
      orderId: data['orderId'] as String,
      userId: data['userId'] as String,
      rating: (data['rating'] as num).toDouble(),
      review: data['review'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'userId': userId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  OrderRating copyWith({
    String? id,
    String? orderId,
    String? userId,
    double? rating,
    String? review,
    DateTime? createdAt,
  }) {
    return OrderRating(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
