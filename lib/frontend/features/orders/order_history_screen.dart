import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/order_card.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import '../menu/menu_provider.dart';
import 'orders_provider.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    final user = ref.watch(authProvider).profile;
    final uid = user?.uid ?? '';

    final activeOrders =
        ref.watch(activeOrdersStreamProvider(uid)).valueOrNull ?? [];
    final historyOrders =
        ref.watch(orderHistoryStreamProvider(uid)).valueOrNull ?? [];
    final menuItems =
        ref.watch(menuStreamProvider).valueOrNull ?? [];

    final allOrders = [...activeOrders, ...historyOrders];

    if (allOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No orders yet',
                style: GoogleFonts.figtree(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: inkCol,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your past orders and favorites will show up here for one-tap reordering.',
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: muteCol,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GhostButton(
                label: 'Start an order',
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Text(
          'Your orders',
          style: GoogleFonts.figtree(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 14),

        // Prominent Active Order Tracking Card (Picture 3 Reference flow)
        if (activeOrders.isNotEmpty) ...[
          GestureDetector(
            onTap: () => context.go('/order/${activeOrders.first.id}'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF382319), Color(0xFF1E1410)]
                      : const [Color(0xFF4A2C1B), Color(0xFF2E190E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E1410).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD49755),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Color(0xFF1E1410),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Delivery: 15–20 mins',
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF7F1EB),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your order is on the way! Tap to track',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: const Color(0xFFD4C8C2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFD49755),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],

        ...allOrders.map((order) {
          return OrderCard(
            order: order,
            onTrack: () => context.go('/order/${order.id}'),
            onReorder: () {
              int addedCount = 0;
              final cartNotifier = ref.read(cartProvider.notifier);

              for (final item in order.items) {
                final menuItem = menuItems.firstWhere(
                  (m) => m.name == item.name || m.id == item.itemId,
                  orElse: () => menuItems.first,
                );

                if (menuItem.isAvailable) {
                  cartNotifier.addLine(
                    menuItem,
                    const CartCustomizations(),
                    item.qty,
                  );
                  addedCount++;
                }
              }

              if (addedCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Added to cart. Check options before checkout.'),
                  ),
                );
                context.go('/cart');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Those items are sold out right now.'),
                  ),
                );
              }
            },
          );
        }),
      ],
    );
  }
}
