import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Represents a physical CafeGO coffee shop branch with GPS coordinates.
class CafeBranch {
  const CafeBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.hours,
    required this.lat,
    required this.lng,
    this.phone = '+63 2 8888 2233',
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String hours;
  final double lat;
  final double lng;
  final String phone;

  LatLng get coordinates => LatLng(lat, lng);
}

/// Official CafeGO Metro Manila flagship branches.
const List<CafeBranch> kCafeBranches = [
  CafeBranch(
    id: 'branch-bgc',
    name: 'CafeGO BGC High Street',
    address: 'Bonifacio High Street, 9th Ave, Taguig',
    city: 'Taguig City',
    hours: '6:30 AM – 11:00 PM Daily',
    lat: 14.5505,
    lng: 121.0514,
  ),
  CafeBranch(
    id: 'branch-makati',
    name: 'CafeGO Ayala Triangle',
    address: 'Ayala Triangle Gardens, Paseo de Roxas, Makati',
    city: 'Makati City',
    hours: '6:00 AM – 10:30 PM Daily',
    lat: 14.5568,
    lng: 121.0234,
  ),
  CafeBranch(
    id: 'branch-qc',
    name: 'CafeGO Katipunan Roastery',
    address: '318 Katipunan Ave, Loyola Heights, Quezon City',
    city: 'Quezon City',
    hours: '7:00 AM – 11:00 PM Daily',
    lat: 14.6416,
    lng: 121.0747,
  ),
  CafeBranch(
    id: 'branch-manila',
    name: 'CafeGO Taft Malate',
    address: '2401 Taft Ave, Malate, Manila',
    city: 'Manila',
    hours: '6:30 AM – 10:00 PM Daily',
    lat: 14.5649,
    lng: 120.9932,
  ),
];

/// Geolocation, distance, ETA, and route interpolation service for CafeGO.
class LocationService {
  const LocationService();

  static const Distance _distance = Distance();

  /// Default Metro Manila fallback coordinates (Makati / BGC corridor).
  static const LatLng defaultCustomerCoordinates = LatLng(14.5535, 121.0365);

  /// Default CafeGO flagship branch.
  static CafeBranch get defaultBranch => kCafeBranches.first;

  /// Finds a [CafeBranch] by ID or name substring, falling back to [defaultBranch].
  static CafeBranch findBranch(String query) {
    final lower = query.toLowerCase();
    return kCafeBranches.firstWhere(
      (b) =>
          b.id.toLowerCase() == lower ||
          b.id.toLowerCase().contains(lower) ||
          b.name.toLowerCase().contains(lower),
      orElse: () => defaultBranch,
    );
  }

  /// Alias for [interpolateAlongRoute].
  static LatLng interpolateLocation(
    LatLng start,
    LatLng end,
    double progress,
  ) =>
      interpolateAlongRoute(start, end, progress);

  /// Computes great-circle distance in kilometers between two coordinates.
  static double computeDistanceKm(LatLng from, LatLng to) {
    final meters = _distance.as(LengthUnit.Meter, from, to);
    return double.parse((meters / 1000.0).toStringAsFixed(2));
  }

  /// Estimates delivery time in minutes based on distance (prep time + rider travel).
  static int computeEtaMinutes(LatLng branch, LatLng destination) {
    final km = computeDistanceKm(branch, destination);
    final travelMins = (km * 3.5).round();
    return (10 + travelMins).clamp(10, 45);
  }

  /// Finds the nearest [CafeBranch] to [target].
  static CafeBranch findNearestBranch(LatLng target) {
    CafeBranch nearest = kCafeBranches.first;
    double minKm = computeDistanceKm(nearest.coordinates, target);
    for (final b in kCafeBranches.skip(1)) {
      final km = computeDistanceKm(b.coordinates, target);
      if (km < minKm) {
        minKm = km;
        nearest = b;
      }
    }
    return nearest;
  }

  /// Generates realistic street-grid route waypoints between [start] and [end].
  static List<LatLng> generateRouteWaypoints(LatLng start, LatLng end) {
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    // Create multi-segment path simulating urban street turns
    return [
      start,
      LatLng(start.latitude + dLat * 0.28, start.longitude + dLng * 0.12),
      LatLng(start.latitude + dLat * 0.52, start.longitude + dLng * 0.48),
      LatLng(start.latitude + dLat * 0.78, start.longitude + dLng * 0.84),
      end,
    ];
  }

  /// Interpolates a position along the route waypoints for [progress] in `0.0..1.0`.
  static LatLng interpolateAlongRoute(
    LatLng start,
    LatLng end,
    double progress,
  ) {
    final t = progress.clamp(0.0, 1.0);
    final waypoints = generateRouteWaypoints(start, end);
    if (t <= 0.0) return waypoints.first;
    if (t >= 1.0) return waypoints.last;

    final segments = waypoints.length - 1;
    final scaled = t * segments;
    final idx = math.min(scaled.floor(), segments - 1);
    final localT = scaled - idx;

    final p0 = waypoints[idx];
    final p1 = waypoints[idx + 1];
    return LatLng(
      p0.latitude + (p1.latitude - p0.latitude) * localT,
      p0.longitude + (p1.longitude - p0.longitude) * localT,
    );
  }

  /// Attempts to acquire the user's current GPS coordinates via [Geolocator].
  /// Falls back gracefully to [defaultCustomerCoordinates] if permissions or services are unavailable.
  Future<LatLng> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return defaultCustomerCoordinates;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return defaultCustomerCoordinates;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return defaultCustomerCoordinates;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return defaultCustomerCoordinates;
    }
  }
}
