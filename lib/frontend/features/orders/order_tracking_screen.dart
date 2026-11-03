import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/frontend/features/menu/menu_provider.dart';
import 'package:orderacoffee/frontend/widgets/cup_icon.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/scooter_delivery_graphic.dart';
import 'orders_provider.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  String _formatOrderCode(String id) {
    if (id.isEmpty) return 'Order #BB2456';
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = clean.length >= 4
        ? clean.substring(clean.length - 4).toUpperCase()
        : clean.toUpperCase().padLeft(4, '0');
    return 'Order #BB$suffix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCanvas = isDark ? const Color(0xFF1E1919) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final lineCol = isDark ? AppColors.lineDark : const Color(0xFFE8DFD5);
    final inkCol = isDark ? AppColors.inkDark : const Color(0xFF1B120C);
    final muteCol = isDark ? AppColors.muteDark : const Color(0xFF7A6D65);
    final brownAccent = isDark ? const Color(0xFFD4A373) : const Color(0xFF3B2314);
    final lightStepBg = isDark ? const Color(0xFF2E2425) : const Color(0xFFD9D4CC);

    final orderAsync = ref.watch(singleOrderStreamProvider(orderId));
    final menuItems = ref.watch(menuStreamProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: orderAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(brownAccent),
            ),
          ),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (order) {
            if (order == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Order not found',
                      style: GoogleFonts.figtree(
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

            // Determine active step index:
            // 0: Confirmed (received)
            // 1: Preparing
            // 2: On the way (ready)
            // 3: Delivered (completed)
            int activeStepIndex = 2; // Default to 'On the way' as in Picture 3
            if (order.status == OrderStatus.received) {
              activeStepIndex = 0;
            } else if (order.status == OrderStatus.preparing) {
              activeStepIndex = 1;
            } else if (order.status == OrderStatus.ready) {
              activeStepIndex = 2;
            } else if (order.status == OrderStatus.completed) {
              activeStepIndex = 3;
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Top App Bar (Picture 3: Back button, Title, More vert)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: inkCol, size: 24),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/orders');
                        }
                      },
                    ),
                    Text(
                      'Order Tracking',
                      style: GoogleFonts.figtree(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: inkCol,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert_rounded, color: inkCol, size: 24),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Order ref: ${order.id}')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Order Number & Estimated Delivery (Picture 3)
                Text(
                  _formatOrderCode(order.id),
                  style: GoogleFonts.figtree(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: inkCol,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Estimated Delivery',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    color: muteCol,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '15–20 mins',
                  style: GoogleFonts.figtree(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: inkCol,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your order is on the way!',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    color: muteCol,
                  ),
                ),

                // Scooter Courier Graphic (Picture 3)
                const ScooterDeliveryGraphic(),

                const SizedBox(height: 6),

                // 4-Stage Horizontal Status Stepper (Picture 3)
                _buildHorizontalStepper(
                  activeStepIndex: activeStepIndex,
                  brownAccent: brownAccent,
                  lightStepBg: lightStepBg,
                  inkCol: inkCol,
                  muteCol: muteCol,
                ),

                const SizedBox(height: 28),

                // Order Details Card (Picture 3)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: lineCol.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: GoogleFonts.figtree(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: inkCol,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // List of items
                      ...order.items.map((item) {
                        // Find thumbnail from catalog
                        final match = menuItems.where((m) => m.name.toLowerCase() == item.name.toLowerCase() || m.id == item.itemId).firstOrNull;
                        final imgUrl = match?.imageUrl;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              // Small item thumbnail (Picture 3)
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5EFE6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: (imgUrl != null && imgUrl.isNotEmpty)
                                    ? Image.network(
                                        imgUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: CupIcon(size: 24, color: Color(0xFF5A3825)),
                                        ),
                                      )
                                    : const Center(
                                        child: CupIcon(size: 24, color: Color(0xFF5A3825)),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.qty} x ${item.name}',
                                      style: GoogleFonts.figtree(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: inkCol,
                                      ),
                                    ),
                                    if (item.customizations.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          item.customizations.values
                                              .where((v) => v != null && v.toString().isNotEmpty)
                                              .map((v) => v is Map ? (v['label'] ?? '') : v.toString())
                                              .where((s) => s.isNotEmpty)
                                              .join(' • '),
                                          style: GoogleFonts.figtree(
                                            fontSize: 12,
                                            color: muteCol,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                peso(item.total),
                                style: GoogleFonts.figtree(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: inkCol,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      Divider(color: lineCol.withValues(alpha: 0.8)),
                      const SizedBox(height: 12),

                      // Total Row (Picture 3)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.figtree(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: inkCol,
                            ),
                          ),
                          Text(
                            peso(order.total),
                            style: GoogleFonts.figtree(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: inkCol,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalStepper({
    required int activeStepIndex,
    required Color brownAccent,
    required Color lightStepBg,
    required Color inkCol,
    required Color muteCol,
  }) {
    final steps = [
      (label: 'Confirmed', icon: Icons.check),
      (label: 'Preparing', icon: Icons.favorite_rounded),
      (label: 'On the way', icon: Icons.favorite_border_rounded),
      (label: 'Delivered', icon: Icons.check),
    ];

    return Column(
      children: [
        // Stepper circles and connecting line
        Stack(
          alignment: Alignment.center,
          children: [
            // Connecting line
            Positioned(
              left: 28,
              right: 28,
              top: 14,
              child: Row(
                children: List.generate(steps.length - 1, (i) {
                  final isPassed = i < activeStepIndex;
                  return Expanded(
                    child: Container(
                      height: 3,
                      color: isPassed ? const Color(0xFFC89568) : lightStepBg,
                    ),
                  );
                }),
              ),
            ),
            // Circular nodes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(steps.length, (index) {
                final isCompleted = index < activeStepIndex;
                final isCurrent = index == activeStepIndex;

                Color circleColor;
                Color iconColor;
                if (isCurrent) {
                  circleColor = brownAccent;
                  iconColor = Colors.white;
                } else if (isCompleted) {
                  circleColor = const Color(0xFFC89568);
                  iconColor = Colors.white;
                } else {
                  circleColor = lightStepBg;
                  iconColor = Colors.white.withValues(alpha: 0.9);
                }

                return Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: brownAccent.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        steps[index].icon,
                        size: 15,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[index].label,
                      style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent || isCompleted ? inkCol : muteCol,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}
