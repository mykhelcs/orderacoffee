import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';

/// Interactive OpenStreetMap widget powered by `flutter_map` and `latlong2`.
///
/// Supports:
/// - **Live Order Tracking Mode**: Displays the CafeGO branch origin marker,
///   customer delivery destination marker, street-route polyline, and live
///   courier/rider marker with distance (km) and ETA badge.
/// - **Interactive Pin Picker Mode** ([onLocationPicked] != null): Allows
///   tapping anywhere on the map (or pressing the GPS recenter button) to
///   pin exact delivery coordinates.
class LiveOrderMap extends StatefulWidget {
  const LiveOrderMap({
    super.key,
    required this.branchLocation,
    this.branchName = 'CafeGO Branch',
    this.customerLocation,
    this.riderLocation,
    this.showRider = false,
    this.height = 220,
    this.onLocationPicked,
    this.onUseMyLocation,
  });

  final LatLng branchLocation;
  final String branchName;
  final LatLng? customerLocation;
  final LatLng? riderLocation;
  final bool showRider;
  final double height;
  final ValueChanged<LatLng>? onLocationPicked;
  final VoidCallback? onUseMyLocation;

  @override
  State<LiveOrderMap> createState() => _LiveOrderMapState();
}

class _LiveOrderMapState extends State<LiveOrderMap> {
  final MapController _mapController = MapController();

  bool get _isTestEnvironment {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding') ||
        bindingName.contains('AutomatedTestWidgetsFlutterBinding');
  }

  LatLng get _effectiveCustomer =>
      widget.customerLocation ?? LocationService.defaultCustomerCoordinates;

  LatLng get _centerPoint {
    if (widget.customerLocation == null) return widget.branchLocation;
    return LatLng(
      (widget.branchLocation.latitude + _effectiveCustomer.latitude) / 2,
      (widget.branchLocation.longitude + _effectiveCustomer.longitude) / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineCol = isDark ? AppColors.lineDark : const Color(0xFFE8DFD5);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final inkCol = isDark ? AppColors.inkDark : const Color(0xFF1B120C);
    final brownAccent =
        isDark ? const Color(0xFFD4A373) : const Color(0xFF3B2314);

    final waypoints = widget.customerLocation != null
        ? LocationService.generateRouteWaypoints(
            widget.branchLocation,
            _effectiveCustomer,
          )
        : <LatLng>[widget.branchLocation];

    final distanceKm = widget.customerLocation != null
        ? LocationService.computeDistanceKm(
            widget.riderLocation ?? widget.branchLocation,
            _effectiveCustomer,
          )
        : 0.0;

    final etaMins = widget.customerLocation != null
        ? LocationService.computeEtaMinutes(
            widget.riderLocation ?? widget.branchLocation,
            _effectiveCustomer,
          )
        : 10;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF251F1E) : const Color(0xFFEDE6DC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: lineCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerPoint,
              initialZoom: 13.8,
              onTap: widget.onLocationPicked != null
                  ? (tapPos, latLng) => widget.onLocationPicked!(latLng)
                  : null,
            ),
            children: [
              if (!_isTestEnvironment)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cafego.orderacoffee',
                ),
              if (waypoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: waypoints,
                      strokeWidth: 4.5,
                      color: const Color(0xFF5A3825),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // 1. CafeGO Store Branch Marker
                  Marker(
                    point: widget.branchLocation,
                    width: 44,
                    height: 44,
                    child: Tooltip(
                      message: widget.branchName,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B2314),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.coffee_rounded,
                          color: Color(0xFFF7F1EB),
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // 2. Customer Delivery Pin Marker
                  if (widget.customerLocation != null)
                    Marker(
                      point: _effectiveCustomer,
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: 'Delivery Destination',
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.bad,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),

                  // 3. Live Rider Scooter Marker
                  if (widget.showRider && widget.riderLocation != null)
                    Marker(
                      point: widget.riderLocation!,
                      width: 48,
                      height: 48,
                      child: Tooltip(
                        message: 'CafeGO Rider',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD49755),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1B120C),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: Color(0xFF1B120C),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top-left Live Telemetry Pill (Distance & Branch)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: lineCol),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: brownAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.customerLocation != null
                        ? '$distanceKm km • ~$etaMins mins'
                        : widget.branchName,
                    style: GoogleFonts.figtree(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: inkCol,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top-right GPS Detect / Recenter Button
          if (widget.onUseMyLocation != null)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: cardBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  onTap: widget.onUseMyLocation,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: lineCol),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.gps_fixed_rounded,
                          size: 14,
                          color: brownAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Use GPS',
                          style: GoogleFonts.figtree(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: inkCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Legend / Instruction Banner
          Positioned(
            bottom: 8,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cardBg.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: lineCol.withValues(alpha: 0.7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.onLocationPicked != null
                          ? 'Tap map to pin exact delivery spot'
                          : 'Origin: ${widget.branchName}',
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.customerLocation != null)
                    Text(
                      '${_effectiveCustomer.latitude.toStringAsFixed(4)}, ${_effectiveCustomer.longitude.toStringAsFixed(4)}',
                      style: GoogleFonts.figtree(
                        fontSize: 10.5,
                        color: inkCol.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
