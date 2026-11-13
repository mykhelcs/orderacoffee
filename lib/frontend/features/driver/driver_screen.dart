import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/app_logo.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/status_badge.dart';

class DriverScreen extends ConsumerStatefulWidget {
  const DriverScreen({super.key});

  @override
  ConsumerState<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends ConsumerState<DriverScreen> {
  bool _isOnline = true;
  String? _activeOrderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    final authState = ref.watch(authProvider);
    final driverProfile = authState.profile;
    final driverUid = driverProfile?.uid ?? 'driver_demo';
    final driverName = driverProfile?.name ?? 'Delivery Partner';
    final rawVehicleType = driverProfile?.vehicleType?.trim();
    final vehicleTypeLabel = (rawVehicleType != null && rawVehicleType.isNotEmpty)
        ? '${rawVehicleType[0].toUpperCase()}${rawVehicleType.substring(1)}'
        : 'Motorcycle';
    final vehiclePlateLabel =
        (driverProfile?.vehicleNumber?.trim().isNotEmpty ?? false)
            ? driverProfile!.vehicleNumber!.trim()
            : 'No plate';
    final ratingLabel = driverProfile?.averageRating != null
        ? driverProfile!.averageRating!.toStringAsFixed(1)
        : 'New';

    final allOrders = ref.watch(allOrdersStreamProvider).valueOrNull ?? [];

    // Find active order assigned to this driver
    Order? activeOrder;
    if (_activeOrderId != null) {
      activeOrder = allOrders.where((o) => o.id == _activeOrderId).firstOrNull;
    }
    activeOrder ??= allOrders.where((o) =>
        o.driverId == driverUid &&
        o.status != OrderStatus.completed &&
        o.status != OrderStatus.cancelled).firstOrNull;

    // Available unassigned delivery orders
    final availableOrders = allOrders.where((o) =>
        o.type == OrderType.delivery &&
        (o.status == OrderStatus.ready || o.status == OrderStatus.preparing) &&
        (o.driverId == null || o.driverId!.isEmpty)).toList();

    // Completed today deliveries
    final completedDeliveries = allOrders.where((o) =>
        o.driverId == driverUid && o.status == OrderStatus.completed).toList();
    final todayEarnings = completedDeliveries.length * 45.0; // ₱45 delivery commission

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: lineCol)),
              ),
              child: Row(
                children: [
                  const AppLogo(fontSize: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: brandCol.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: brandCol.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.two_wheeler_rounded, size: 12, color: Color(0xFFD4A373)),
                        const SizedBox(width: 4),
                        Text(
                          'DRIVER WORKSPACE',
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: brandCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Sign Out',
                    icon: Icon(Icons.logout_rounded, size: 20, color: muteCol),
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Driver Status Banner ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: lineCol),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: brandCol.withValues(alpha: 0.15),
                      child: Icon(Icons.person_pin_circle_rounded, color: brandCol, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                          ),
                          Text(
                            '$vehicleTypeLabel • $vehiclePlateLabel • ⭐ $ratingLabel',
                            style: GoogleFonts.figtree(fontSize: 12, color: muteCol),
                          ),
                        ],
                      ),
                    ),
                    // Online Toggle Switch
                    Column(
                      children: [
                        Switch.adaptive(
                          value: _isOnline,
                          activeTrackColor: Colors.green,
                          onChanged: (val) => setState(() => _isOnline = val),
                        ),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Earnings Summary Cards ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lineCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Today Earnings', style: GoogleFonts.figtree(fontSize: 11, color: muteCol)),
                          const SizedBox(height: 4),
                          Text(
                            peso(todayEarnings),
                            style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w800, color: brandCol),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lineCol),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Completed', style: GoogleFonts.figtree(fontSize: 11, color: muteCol)),
                          const SizedBox(height: 4),
                          Text(
                            '${completedDeliveries.length} trips',
                            style: GoogleFonts.figtree(fontSize: 18, fontWeight: FontWeight.w800, color: inkCol),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Active Delivery vs Available Pool ──
            Expanded(
              child: activeOrder != null
                  ? _buildActiveDeliveryView(context, activeOrder, cardBg, lineCol, inkCol, muteCol, brandCol)
                  : _buildAvailableDeliveriesPool(
                      context,
                      availableOrders,
                      cardBg,
                      lineCol,
                      inkCol,
                      muteCol,
                      brandCol,
                      driverUid,
                      driverName,
                      driverProfile?.phone,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryView(
    BuildContext context,
    Order order,
    Color cardBg,
    Color lineCol,
    Color inkCol,
    Color muteCol,
    Color brandCol,
  ) {
    final isCOD = order.payment == PaymentMethod.cash;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.navigation_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE DELIVERY IN PROGRESS',
                      style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green[800]),
                    ),
                    Text(
                      'Destination: ${order.address ?? 'Standard Delivery'}',
                      style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: inkCol),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Customer Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lineCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.userName.isNotEmpty ? order.userName : 'Customer',
                    style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w700, color: inkCol),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Payment: ${order.payment.label} (${isCOD ? 'COLLECT CASH' : 'PREPAID ONLINE'})',
                style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: isCOD ? Colors.amber[800] : Colors.green),
              ),
              const SizedBox(height: 8),
              Text('Items: ${order.items.map((i) => '${i.qty}x ${i.name}').join(', ')}', style: GoogleFonts.figtree(color: muteCol, fontSize: 13)),
              if ((order.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Note: ${order.note}', style: GoogleFonts.figtree(fontSize: 12, color: AppColors.crema)),
              ],
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Call Customer',
                      icon: Icons.phone_in_talk_rounded,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dialing ${order.userName}...')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GhostButton(
                      label: 'Advance GPS',
                      icon: Icons.gps_fixed_rounded,
                      onPressed: () async {
                        try {
                          await ref.read(adminProvider).advanceRiderGps(order);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Live GPS location updated on map!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update GPS: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (order.status == OrderStatus.ready)
                BrandButton(
                  label: isCOD ? 'Complete & Collect ${peso(order.total)}' : 'Complete Delivery',
                  onPressed: () async {
                    try {
                      await ref
                          .read(orderRepositoryProvider)
                          .advanceStatus(order.id, OrderStatus.completed);
                      if (!mounted) return;
                      setState(() => _activeOrderId = null);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Delivery completed! Earnings added to your wallet 🎉'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unable to complete delivery: $e')),
                        );
                      }
                    }
                  },
                )
              else
                const BrandButton(
                  label: 'Waiting for Kitchen to mark Ready',
                  onPressed: null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableDeliveriesPool(
    BuildContext context,
    List<Order> orders,
    Color cardBg,
    Color lineCol,
    Color inkCol,
    Color muteCol,
    Color brandCol,
    String driverUid,
    String driverName,
    String? driverPhone,
  ) {
    if (!_isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime_outlined, size: 48, color: muteCol),
            const SizedBox(height: 12),
            Text(
              'You are Currently Offline',
              style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: inkCol),
            ),
            Text('Turn switch online above to view available delivery orders.', style: GoogleFonts.figtree(color: muteCol)),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.moped_rounded, size: 48, color: brandCol),
            const SizedBox(height: 12),
            Text(
              'Looking for Delivery Orders...',
              style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: inkCol),
            ),
            Text('New delivery tickets will appear here in real-time.', style: GoogleFonts.figtree(color: muteCol)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Available Orders Pool (${orders.length})',
            style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: inkCol),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: lineCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          o.userName.isNotEmpty ? o.userName : 'Customer',
                          style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: inkCol),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+₱45 Fee',
                            style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green[800]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Address: ${o.address ?? 'Customer delivery point'}', style: GoogleFonts.figtree(fontSize: 12.5, color: muteCol)),
                    Text('${o.items.length} items • ${o.payment.label}', style: GoogleFonts.figtree(fontSize: 12, color: muteCol)),
                    const SizedBox(height: 10),
                    BrandButton(
                      label: 'Accept Delivery',
                      onPressed: () async {
                        try {
                          await ref.read(adminProvider).assignDriver(
                                o.id,
                                driverId: driverUid,
                                driverName: driverName,
                                driverPhone: (driverPhone != null && driverPhone.trim().isNotEmpty)
                                    ? driverPhone.trim()
                                    : null,
                              );
                          if (!mounted) return;
                          setState(() => _activeOrderId = o.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Accepted delivery for ${o.userName}! Pick up at cafe.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unable to accept delivery: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
