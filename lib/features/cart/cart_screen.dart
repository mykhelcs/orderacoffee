import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/cart_line.dart';
import '../../widgets/brand_button.dart';
import '../../widgets/ghost_button.dart';
import '../menu/item_detail_sheet.dart';
import '../menu/menu_provider.dart';
import 'cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  String _formatCustomizationSummary(CartCustomizations c) {
    final parts = <String>[];
    if (c.size != null) parts.add(c.size!.label);
    if (c.milk != null) parts.add(c.milk!.label);
    if (c.sugar != null) parts.add('${c.sugar} sugar');
    if (c.ice != null) parts.add(c.ice!);
    if (c.addOns.isNotEmpty) {
      parts.add(c.addOns.map((a) => a.label).join(', '));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    final cart = ref.watch(cartProvider);
    final menuItems = ref.watch(menuStreamProvider).valueOrNull ?? [];

    if (cart.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your cart is empty',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: inkCol,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a drink from the menu to start your order.',
                style: GoogleFonts.figtree(
                  fontSize: 14,
                  color: muteCol,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GhostButton(
                label: 'Browse menu',
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
          'Your cart',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 12),
        ...cart.lines.map((line) {
          final summary = _formatCustomizationSummary(line.customizations);

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
                // Top row: Qty x Name and line total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${line.qty}× ${line.name}',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: inkCol,
                        ),
                      ),
                    ),
                    Text(
                      peso(line.lineTotal),
                      style: GoogleFonts.figtree(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: inkCol,
                      ),
                    ),
                  ],
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: muteCol,
                    ),
                  ),
                ],
                if (line.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: ${line.note}',
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      color: muteCol,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    GhostButton(
                      label: 'Edit',
                      onPressed: () {
                        final menuItem = menuItems.firstWhere(
                          (i) => i.id == line.itemId,
                          orElse: () => menuItems.first,
                        );
                        ItemDetailSheet.show(
                          context,
                          menuItem,
                          editLine: line,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'Remove',
                      onPressed: () {
                        ref.read(cartProvider.notifier).removeLine(line.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Total row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: GoogleFonts.figtree(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: inkCol,
              ),
            ),
            Text(
              peso(cart.total),
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: inkCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        BrandButton(
          label: 'Go to checkout',
          trailing: peso(cart.total),
          onPressed: () => context.go('/checkout'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
