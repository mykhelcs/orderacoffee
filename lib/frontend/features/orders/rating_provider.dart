import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orderacoffee/backend/models/order_rating.dart';
import 'package:orderacoffee/backend/repositories/rating_repository.dart';

final ratingRepositoryProvider = Provider((ref) => RatingRepository());

/// Provider to check if user has rated an order
final userHasRatedProvider = FutureProvider.family<bool, ({String orderId, String userId})>(
  (ref, params) async {
    final repository = ref.watch(ratingRepositoryProvider);
    return repository.hasRated(
      orderId: params.orderId,
      userId: params.userId,
    );
  },
);

/// Provider to get user's rating for an order
final userRatingProvider = FutureProvider.family<OrderRating?, ({String orderId, String userId})>(
  (ref, params) async {
    final repository = ref.watch(ratingRepositoryProvider);
    return repository.getRating(
      orderId: params.orderId,
      userId: params.userId,
    );
  },
);

/// Provider to get all ratings for an order
final orderRatingsProvider = FutureProvider.family<List<OrderRating>, String>(
  (ref, orderId) async {
    final repository = ref.watch(ratingRepositoryProvider);
    return repository.getOrderRatings(orderId);
  },
);

/// Provider to get average rating for an order
final averageRatingProvider = FutureProvider.family<double, String>(
  (ref, orderId) async {
    final repository = ref.watch(ratingRepositoryProvider);
    return repository.getAverageRating(orderId);
  },
);
