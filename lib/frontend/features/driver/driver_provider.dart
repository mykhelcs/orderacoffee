import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import '../auth/auth_provider.dart';
import '../orders/orders_provider.dart';

/// Coordinates driver-specific delivery mutations without coupling to AdminNotifier.
class DriverNotifier {
  DriverNotifier(this._ref);

  final Ref _ref;

  Future<void> acceptDelivery(
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

  Future<void> completeDelivery(String orderId) async {
    await _ref
        .read(orderRepositoryProvider)
        .advanceStatus(orderId, OrderStatus.completed);
  }

  Future<void> setAvailability(String uid, bool isAvailable) async {
    if (uid.isEmpty || uid.startsWith('preview-') || uid == 'driver_demo') {
      return;
    }
    await _ref.read(userRepositoryProvider).setDriverAvailability(
          uid,
          isAvailable,
        );
  }
}

final driverProvider = Provider<DriverNotifier>((ref) {
  return DriverNotifier(ref);
});
