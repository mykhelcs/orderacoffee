import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/order.dart';
import '../../widgets/order_card.dart';
import '../menu/menu_provider.dart';
import '../orders/orders_provider.dart';
import 'admin_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    final queue = ref.watch(liveQueueStreamProvider).valueOrNull ?? [];
    final menuItems = ref.watch(menuStreamProvider).valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Live Queue Header
        Text(
          'Live queue',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 12),
        if (queue.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  'Queue is clear',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: inkCol,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'New orders appear here automatically.',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    color: muteCol,
                  ),
                ),
              ],
            ),
          )
        else
          ...queue.map((order) {
            final nextStatus = _getNextStatus(order.status);
            return OrderCard(
              order: order,
              isStaffView: true,
              onAdvance: nextStatus != null
                  ? () async {
                      await ref
                          .read(adminProvider)
                          .advanceOrder(order.id, nextStatus);
                      if (context.mounted) {
                        final label =
                            kOrderLabels[nextStatus.name] ?? nextStatus.name;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${order.id} is now ${label.toLowerCase()}',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            );
          }),
        const SizedBox(height: 20),
        // Availability Header
        Text(
          'Availability',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 12),
        if (menuItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No menu items found in database',
                style: GoogleFonts.figtree(color: muteCol),
              ),
            ),
          )
        else
          ...menuItems.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lineCol),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.figtree(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: item.isAvailable,
                    activeTrackColor: AppColors.ok,
                    onChanged: (val) async {
                      await ref
                          .read(adminProvider)
                          .toggleItemAvailability(item.id, val);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? '${item.name} is available'
                                  : '${item.name} marked sold out',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}
