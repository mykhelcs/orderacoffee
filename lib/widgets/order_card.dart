import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/models/order.dart';
import 'brand_button.dart';
import 'ghost_button.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTrack,
    this.onReorder,
    this.onAdvance,
    this.isStaffView = false,
  });

  final Order order;
  final VoidCallback? onTrack;
  final VoidCallback? onReorder;
  final VoidCallback? onAdvance;
  final bool isStaffView;

  String _itemsSummary() {
    return order.items.map((i) => '${i.qty}× ${i.name}').join(', ');
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
      OrderType.delivery => 'Delivery',
      OrderType.pickup => 'Pickup',
    };

    final nextLabel = _nextStatusLabel();

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
          // Row: Order ID + Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.id,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: inkCol,
                ),
              ),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          // Items and metadata
          Text(
            isStaffView
                ? '${_itemsSummary()}\n$typeDescription'
                : '${_itemsSummary()} · ${peso(order.total)}',
            style: GoogleFonts.figtree(
              fontSize: 13,
              color: muteCol,
              height: 1.4,
            ),
          ),
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
          if (isStaffView && nextLabel != null && onAdvance != null) ...[
            const SizedBox(height: 12),
            BrandButton(
              label: 'Mark as ${kOrderLabels[nextLabel]?.toLowerCase() ?? nextLabel}',
              onPressed: onAdvance,
            ),
          ],
        ],
      ),
    );
  }
}
