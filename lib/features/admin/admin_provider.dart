import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/order.dart';
import '../menu/menu_provider.dart';
import '../orders/orders_provider.dart';

class AdminNotifier {
  AdminNotifier(this._ref);

  final Ref _ref;

  Future<void> advanceOrder(String orderId, OrderStatus next) async {
    await _ref.read(orderRepositoryProvider).advanceStatus(orderId, next);
  }

  Future<void> toggleItemAvailability(String itemId, bool isAvailable) async {
    await _ref.read(menuRepositoryProvider).toggleSoldOut(itemId, isAvailable);
  }
}

final adminProvider = Provider<AdminNotifier>((ref) {
  return AdminNotifier(ref);
});
