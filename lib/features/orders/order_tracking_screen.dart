import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/order.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/step_tracker.dart';
import 'orders_provider.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    final orderAsync = ref.watch(singleOrderStreamProvider(orderId));

    return Scaffold(
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (order) {
            if (order == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Order not found',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GhostButton(
                      label: 'View all orders',
                      onPressed: () => context.go('/orders'),
                    ),
                  ],
                ),
              );
            }

            final typeDescription = switch (order.type) {
              OrderType.dineIn => 'Table ${order.tableNo ?? '-'}',
              OrderType.delivery => order.address ?? 'Delivery',
              OrderType.pickup => 'Pickup at the counter',
            };

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                Row(
                  children: [
                    GhostButton(
                      label: 'All orders',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.go('/orders'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status & Stepper Card
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
                            'Order ${order.id}',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: inkCol,
                            ),
                          ),
                          StatusBadge(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StepTracker(status: order.status),
                      const SizedBox(height: 12),
                      Divider(color: lineCol),
                      const SizedBox(height: 8),
                      Text(
                        '$typeDescription · ${peso(order.total)}',
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          color: muteCol,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Items breakdown Card
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
                      ...List.generate(order.items.length, (idx) {
                        final item = order.items[idx];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: idx == order.items.length - 1 ? 0 : 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.qty}× ${item.name}',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: inkCol,
                                    ),
                                  ),
                                  Text(
                                    peso(item.total),
                                    style: GoogleFonts.figtree(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: inkCol,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.customizations.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.customizations.values
                                      .where((v) =>
                                          v != null && v.toString().isNotEmpty)
                                      .join(' · '),
                                  style: GoogleFonts.figtree(
                                    fontSize: 13,
                                    color: muteCol,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Status updates here as soon as the barista changes it.',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    color: muteCol,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}
