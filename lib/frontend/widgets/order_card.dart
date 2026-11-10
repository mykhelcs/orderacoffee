import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'brand_button.dart';
import 'ghost_button.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onTrack,
    this.onReorder,
    this.onAdvance,
    this.onCancel,
    this.onUpdateRiderGps,
    this.isStaffView = false,
  });

  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;
  final VoidCallback? onReorder;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;
  final VoidCallback? onUpdateRiderGps;
  final bool isStaffView;

  String _itemsSummary() {
    return order.items.map((i) {
      if (!isStaffView) return '${i.qty}x ${i.name}';
      final custom = i.customizationSummary;
      final noteStr = i.note.isNotEmpty ? ' [Note: ${i.note}]' : '';
      return custom.isNotEmpty
          ? '${i.qty}x ${i.name} ($custom)$noteStr'
          : '${i.qty}x ${i.name}$noteStr';
    }).join(isStaffView ? '\n' : ', ');
  }

  String? _nextStatusLabel() {
    switch (order.status) {
      case OrderStatus.received:
        return 'preparing';
      case OrderStatus.preparing:
        return 'ready';
      case OrderStatus.ready:
        return 'completed';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    final typeDescription = switch (order.type) {
      OrderType.dineIn => 'Table ${order.tableNo ?? '-'}',
      OrderType.delivery =>
        order.address != null && order.address!.isNotEmpty
            ? 'Delivery • ${order.address}'
            : 'Delivery',
      OrderType.pickup => 'Pickup',
    };

    final nextLabel = _nextStatusLabel();

    final cardContent = Container(
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
          // Row: Customer Name (staff view) / Order ID + Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isStaffView
                      ? (order.userName.trim().isNotEmpty
                          ? order.userName
                          : 'Customer')
                      : order.id,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: inkCol,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          // Items and metadata
          Text(
            isStaffView
                ? '${_itemsSummary()}\n$typeDescription • ${order.payment.label} (${order.paymentStatus.name.toUpperCase()}) • ${peso(order.total)}'
                : '${_itemsSummary()} • ${peso(order.total)}',
            style: GoogleFonts.figtree(
              fontSize: 13,
              color: muteCol,
              height: 1.4,
            ),
          ),
          if (isStaffView && (order.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Order Note: ${order.note}',
              style: GoogleFonts.figtree(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.crema,
              ),
            ),
          ],
          // Action buttons
          if (!isStaffView) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onTrack != null)
                  GhostButton(
                    label: 'Track',
                    onPressed: onTrack,
                  ),
                if (onTrack != null && onReorder != null)
                  const SizedBox(width: 8),
                if (onReorder != null)
                  GhostButton(
                    label: 'Reorder',
                    onPressed: onReorder,
                  ),
              ],
            ),
          ],
          if (isStaffView) ...[
            if (nextLabel != null && onAdvance != null) ...[
              const SizedBox(height: 12),
              BrandButton(
                label:
                    'Mark as ${kOrderLabels[nextLabel]?.toLowerCase() ?? nextLabel}',
                onPressed: onAdvance,
              ),
            ],
            if ((onCancel != null && order.status == OrderStatus.received) ||
                (onUpdateRiderGps != null &&
                    order.type == OrderType.delivery &&
                    order.status == OrderStatus.ready)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onCancel != null && order.status == OrderStatus.received)
                    GhostButton(
                      label: 'Cancel order',
                      onPressed: onCancel,
                    ),
                  if (onUpdateRiderGps != null &&
                      order.type == OrderType.delivery &&
                      order.status == OrderStatus.ready)
                    GhostButton(
                      label: 'Advance Rider GPS',
                      icon: Icons.delivery_dining_rounded,
                      onPressed: onUpdateRiderGps,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }

    return cardContent;
  }
}
