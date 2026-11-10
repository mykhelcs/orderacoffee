import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/features/admin/admin_provider.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/status_badge.dart';

class OrderDetailsModal extends ConsumerStatefulWidget {
  const OrderDetailsModal({
    super.key,
    required this.order,
  });

  final Order order;

  static Future<void> show(BuildContext context, Order order) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderDetailsModal(order: order),
    );
  }

  @override
  ConsumerState<OrderDetailsModal> createState() => _OrderDetailsModalState();
}

class _OrderDetailsModalState extends ConsumerState<OrderDetailsModal> {
  late Order _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  OrderStatus? _getNextStatus(OrderStatus current) {
    switch (current) {
      case OrderStatus.received:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
        return OrderStatus.completed;
      default:
        return null;
    }
  }

  void _showDriverAssignmentDialog(List<UserProfile> drivers) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Assign Driver for ${_currentOrder.userName}',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
          ),
          content: drivers.isEmpty
              ? const Text('No registered drivers found in the system.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final driver = drivers[i];
                      final isCurrent = _currentOrder.driverId == driver.uid;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFD4A373).withValues(alpha: 0.2),
                          child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFD4A373)),
                        ),
                        title: Text(
                          driver.name,
                          style: GoogleFonts.figtree(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${driver.phone ?? 'No phone'} • ${driver.vehicleType ?? 'Motorcycle'}',
                          style: GoogleFonts.figtree(fontSize: 12),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref.read(adminProvider).assignDriver(
                                _currentOrder.id,
                                driverId: driver.uid,
                                driverName: driver.name,
                                driverPhone: driver.phone,
                              );
                          setState(() {
                            _currentOrder = _currentOrder.copyWith(
                              driverId: driver.uid,
                              driverName: driver.name,
                              driverPhone: driver.phone,
                              driverStatus: 'assigned',
                            );
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Assigned delivery to ${driver.name}')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    final allUsers = ref.watch(allUsersStreamProvider).valueOrNull ?? [];
    final drivers = allUsers.where((u) => u.isDriver).toList();

    final nextStatus = _getNextStatus(_currentOrder.status);
    final dateStr = _currentOrder.createdAt != null
        ? DateFormat('MMMM d, y • h:mm a').format(_currentOrder.createdAt!)
        : 'Recently placed';

    final displayName = _currentOrder.userName.trim().isNotEmpty
        ? _currentOrder.userName
        : 'Customer';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: lineCol),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: lineCol,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: inkCol,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateStr,
                            style: GoogleFonts.figtree(
                              fontSize: 12.5,
                              color: muteCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: _currentOrder.status),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: muteCol),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Scrollable Order Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Order Type Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: brandCol.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: brandCol.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentOrder.type == OrderType.delivery
                                ? Icons.delivery_dining_rounded
                                : _currentOrder.type == OrderType.dineIn
                                    ? Icons.table_restaurant_rounded
                                    : Icons.storefront_rounded,
                            color: brandCol,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentOrder.type == OrderType.delivery
                                      ? 'Delivery Order'
                                      : _currentOrder.type == OrderType.dineIn
                                          ? 'Dine-In • Table ${_currentOrder.tableNo ?? '-'}'
                                          : 'Pick-Up Order',
                                  style: GoogleFonts.figtree(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: inkCol,
                                  ),
                                ),
                                if (_currentOrder.address != null &&
                                    _currentOrder.address!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _currentOrder.address!,
                                      style: GoogleFonts.figtree(
                                        fontSize: 12,
                                        color: muteCol,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Driver Synchronization Info (for Delivery)
                    if (_currentOrder.type == OrderType.delivery) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF261E1C) : const Color(0xFFF9F5F1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: lineCol),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFD4A373).withValues(alpha: 0.2),
                              child: const Icon(Icons.two_wheeler_rounded, size: 20, color: Color(0xFFD4A373)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentOrder.driverName != null && _currentOrder.driverName!.isNotEmpty
                                        ? 'Driver: ${_currentOrder.driverName}'
                                        : 'No Driver Assigned',
                                    style: GoogleFonts.figtree(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: inkCol,
                                    ),
                                  ),
                                  Text(
                                    _currentOrder.driverStatus != null
                                        ? 'Status: ${_currentOrder.driverStatus!.toUpperCase()}'
                                        : 'Waiting for driver assignment',
                                    style: GoogleFonts.figtree(fontSize: 11.5, color: muteCol),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showDriverAssignmentDialog(drivers),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                              label: Text(_currentOrder.driverId != null ? 'Reassign' : 'Assign'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Items List Header
                    Text(
                      'Items Ordered (${_currentOrder.items.length})',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Items breakdown
                    ..._currentOrder.items.map((item) {
                      final custom = item.customizationSummary;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2B2220) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: lineCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.qty}x ${item.name}',
                                  style: GoogleFonts.figtree(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: inkCol,
                                  ),
                                ),
                                Text(
                                  peso(item.total),
                                  style: GoogleFonts.figtree(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: brandCol,
                                  ),
                                ),
                              ],
                            ),
                            if (custom.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                custom,
                                style: GoogleFonts.figtree(
                                  fontSize: 12,
                                  color: muteCol,
                                ),
                              ),
                            ],
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Note: ${item.note}',
                                style: GoogleFonts.figtree(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.crema,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    if ((_currentOrder.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.note_alt_outlined, size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Order Note: ${_currentOrder.note}',
                                style: GoogleFonts.figtree(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: inkCol,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Financial Summary Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF261E1C) : const Color(0xFFFBF8F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lineCol),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal', peso(_currentOrder.computedSubtotal), inkCol, muteCol),
                          if (_currentOrder.deliveryFee > 0)
                            _buildSummaryRow('Delivery Fee', peso(_currentOrder.deliveryFee), inkCol, muteCol),
                          if (_currentOrder.discount > 0)
                            _buildSummaryRow('Discount', '-${peso(_currentOrder.discount)}', Colors.green, muteCol),
                          const Divider(height: 16),
                          _buildSummaryRow(
                            'Total Amount',
                            peso(_currentOrder.total),
                            brandCol,
                            inkCol,
                            isBold: true,
                            fontSize: 16,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment: ${_currentOrder.payment.label}',
                                style: GoogleFonts.figtree(fontSize: 12, color: muteCol),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _currentOrder.paymentStatus == PaymentStatus.paid
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _currentOrder.paymentStatus.name.toUpperCase(),
                                  style: GoogleFonts.figtree(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _currentOrder.paymentStatus == PaymentStatus.paid
                                        ? Colors.green
                                        : Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: lineCol)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (nextStatus != null)
                        BrandButton(
                          label: 'Advance to ${kOrderLabels[nextStatus.name] ?? nextStatus.name}',
                          onPressed: () async {
                            await ref.read(adminProvider).advanceOrder(_currentOrder.id, nextStatus);
                            setState(() {
                              _currentOrder = _currentOrder.copyWith(status: nextStatus);
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Order advanced to ${nextStatus.name}')),
                              );
                            }
                          },
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_currentOrder.type == OrderType.delivery &&
                              _currentOrder.status == OrderStatus.ready) ...[
                            Expanded(
                              child: GhostButton(
                                label: 'Advance GPS',
                                icon: Icons.delivery_dining_rounded,
                                onPressed: () async {
                                  await ref.read(adminProvider).advanceRiderGps(_currentOrder);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Simulated rider GPS location advance')),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_currentOrder.status == OrderStatus.received ||
                              _currentOrder.status == OrderStatus.preparing)
                            Expanded(
                              child: GhostButton(
                                label: 'Cancel Order',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Confirm Cancellation'),
                                      content: Text('Cancel order for $displayName?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c, false),
                                          child: const Text('No'),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                          onPressed: () => Navigator.pop(c, true),
                                          child: const Text('Yes, Cancel'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref.read(adminProvider).cancelOrder(_currentOrder.id);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color valCol,
    Color labelCol, {
    bool isBold = false,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: labelCol,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.figtree(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valCol,
            ),
          ),
        ],
      ),
    );
  }
}
