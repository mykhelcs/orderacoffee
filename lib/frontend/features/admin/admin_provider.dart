import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/repositories/reports_repository.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import '../auth/auth_provider.dart';
import '../menu/menu_provider.dart';
import '../orders/orders_provider.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final storeStatusProvider = StateProvider<bool>((ref) => true);

final allOrdersStreamProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).liveQueue();
});

final allUsersStreamProvider = StreamProvider<List<UserProfile>>((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers();
});

final completedTodayProvider = FutureProvider<List<Order>>((ref) async {
  // Watch live queue so completedToday refreshes whenever an order completes
  ref.watch(liveQueueStreamProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return ref.watch(orderRepositoryProvider).getCompletedToday(startOfDay);
});

final topSellingItemsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final completedToday = await ref.watch(completedTodayProvider.future);
  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final items = await ref.watch(reportsRepositoryProvider).getTopItems(
          from: startOfMonth,
          to: now.add(const Duration(days: 1)),
        );
    if (items.isNotEmpty) return items;
  } catch (_) {
    // Fallback to aggregating from completedToday when offline/local
  }

  final countMap = <String, int>{};
  final nameMap = <String, String>{};
  final revenueMap = <String, double>{};

  for (final order in completedToday) {
    for (final item in order.items) {
      countMap[item.itemId] = (countMap[item.itemId] ?? 0) + item.qty;
      nameMap[item.itemId] = item.name;
      revenueMap[item.itemId] = (revenueMap[item.itemId] ?? 0.0) + item.total;
    }
  }

  final sortedKeys = countMap.keys.toList()
    ..sort((a, b) => (countMap[b] ?? 0).compareTo(countMap[a] ?? 0));

  return sortedKeys.map((itemId) {
    return {
      'itemId': itemId,
      'name': nameMap[itemId] ?? '',
      'qty': countMap[itemId] ?? 0,
      'revenue': revenueMap[itemId] ?? 0.0,
    };
  }).toList();
});

class AdminNotifier {
  AdminNotifier(this._ref);

  final Ref _ref;

  Future<void> advanceOrder(String orderId, OrderStatus next) async {
    await _ref.read(orderRepositoryProvider).advanceStatus(orderId, next);
    _ref.invalidate(completedTodayProvider);
    _ref.invalidate(topSellingItemsProvider);
  }

  Future<void> cancelOrder(String orderId) async {
    await _ref.read(orderRepositoryProvider).cancelOrder(orderId);
  }

  Future<void> assignDriver(
    String orderId, {
    required String driverId,
    required String driverName,
    String? driverPhone,
  }) async {
    await _ref.read(orderRepositoryProvider).assignDriver(
          orderId,
          driverId: driverId,
          driverName: driverName,
          driverPhone: driverPhone,
        );
  }

  Future<void> advanceRiderGps(Order order) async {
    final branch = (order.branchLat != null && order.branchLng != null)
        ? LatLng(order.branchLat!, order.branchLng!)
        : LocationService.defaultBranch.coordinates;
    final dest = (order.deliveryLat != null && order.deliveryLng != null)
        ? LatLng(order.deliveryLat!, order.deliveryLng!)
        : LocationService.defaultCustomerCoordinates;
    final current = (order.riderLat != null && order.riderLng != null)
        ? LatLng(order.riderLat!, order.riderLng!)
        : branch;

    final nextPos = LocationService.interpolateLocation(current, dest, 0.45);
    await _ref.read(orderRepositoryProvider).updateRiderLocation(
          order.id,
          nextPos.latitude,
          nextPos.longitude,
        );
  }

  Future<void> toggleItemAvailability(String itemId, bool isAvailable) async {
    await _ref.read(menuRepositoryProvider).toggleSoldOut(itemId, isAvailable);
  }

  Future<void> updateItemStock(String itemId, int newStock) async {
    await _ref.read(menuRepositoryProvider).updateStock(itemId, newStock);
  }

  Future<void> toggleItemHidden(String itemId, bool isHidden) async {
    await _ref.read(menuRepositoryProvider).toggleHidden(itemId, isHidden);
  }

  Future<String> createMenuItem(MenuItem item) async {
    return _ref.read(menuRepositoryProvider).createItem(item);
  }

  Future<void> updateMenuItem(MenuItem item) async {
    await _ref.read(menuRepositoryProvider).updateItem(item.id, item.toMap());
  }

  Future<void> deleteMenuItem(String itemId) async {
    await _ref.read(menuRepositoryProvider).deleteItem(itemId);
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    await _ref.read(userRepositoryProvider).updateRole(uid, newRole);
    _ref.invalidate(allUsersStreamProvider);
  }

  void toggleStoreStatus(bool isOpen) {
    _ref.read(storeStatusProvider.notifier).state = isOpen;
  }
}

final adminProvider = Provider<AdminNotifier>((ref) {
  return AdminNotifier(ref);
});
