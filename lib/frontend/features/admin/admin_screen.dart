import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/seed/seed_menu_data.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/order_card.dart';
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

  void _showMenuItemEditor(
    BuildContext context,
    WidgetRef ref, {
    MenuItem? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.basePrice.toStringAsFixed(0) : '150',
    );
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final imgCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    String selectedCat = existing?.category ?? 'Hot Coffee';

    const categories = [
      'Hot Coffee',
      'Iced Coffee',
      'Non-Coffee',
      'Pastries',
      'Merch',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Menu Item' : 'Edit Menu Item',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categories.contains(selectedCat)
                          ? selectedCat
                          : categories.first,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCat = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Base Price (₱)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: imgCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Image URL'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                BrandButton(
                  label: existing == null ? 'Create' : 'Save',
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final price =
                        double.tryParse(priceCtrl.text.trim()) ?? 150.0;
                    if (name.isEmpty) return;

                    final isCoffee = selectedCat == 'Hot Coffee' ||
                        selectedCat == 'Iced Coffee';

                    final item = MenuItem(
                      id: existing?.id ??
                          'item_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      category: selectedCat,
                      description: descCtrl.text.trim(),
                      basePrice: price,
                      imageUrl: imgCtrl.text.trim().isEmpty
                          ? null
                          : imgCtrl.text.trim(),
                      isAvailable: existing?.isAvailable ?? true,
                      isHidden: existing?.isHidden ?? false,
                      options: existing?.options ??
                          (isCoffee ? defaultDrinkOptions : const MenuOptions()),
                    );

                    try {
                      if (existing == null) {
                        await ref.read(adminProvider).createMenuItem(item);
                      } else {
                        await ref.read(adminProvider).updateMenuItem(item);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error saving item: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
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
    final menuItems = ref.watch(allMenuStreamProvider).valueOrNull ??
        ref.watch(menuStreamProvider).valueOrNull ??
        [];
    final completedToday =
        ref.watch(completedTodayProvider).valueOrNull ?? const <Order>[];
    final topSelling =
        ref.watch(topSellingItemsProvider).valueOrNull ?? const [];

    final todayRevenue =
        completedToday.fold<double>(0.0, (sum, o) => sum + o.total);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Sales & Analytics Summary Bar
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: "Today's Sales",
                value: peso(todayRevenue),
                subtitle: '${completedToday.length} completed',
                cardBg: cardBg,
                lineCol: lineCol,
                inkCol: inkCol,
                muteCol: muteCol,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Active Queue',
                value: '${queue.length}',
                subtitle: topSelling.isNotEmpty
                    ? 'Top: ${topSelling.first['name']}'
                    : 'Real-time orders',
                cardBg: cardBg,
                lineCol: lineCol,
                inkCol: inkCol,
                muteCol: muteCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Live Queue Header
        Text(
          'Live queue',
          style: GoogleFonts.playfairDisplay(
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
                  style: GoogleFonts.playfairDisplay(
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
              onCancel: order.status == OrderStatus.received
                  ? () async {
                      await ref.read(adminProvider).cancelOrder(order.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Order ${order.id} cancelled'),
                          ),
                        );
                      }
                    }
                  : null,
              onUpdateRiderGps: order.type == OrderType.delivery &&
                      order.status == OrderStatus.ready
                  ? () async {
                      await ref.read(adminProvider).advanceRiderGps(order);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Updated rider GPS for ${order.id}',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            );
          }),
        const SizedBox(height: 20),
        // Availability & Menu Catalog Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Availability',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: inkCol,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showMenuItemEditor(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Item'),
            ),
          ],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.figtree(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: inkCol,
                          ),
                        ),
                        Text(
                          '${item.category} • ${peso(item.basePrice)}${item.isHidden ? ' • Hidden' : ''}',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            color: muteCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit item',
                    icon: Icon(Icons.edit_outlined, size: 18, color: muteCol),
                    onPressed: () =>
                        _showMenuItemEditor(context, ref, existing: item),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.cardBg,
    required this.lineCol,
    required this.inkCol,
    required this.muteCol,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color cardBg;
  final Color lineCol;
  final Color inkCol;
  final Color muteCol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muteCol,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: inkCol,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.figtree(
              fontSize: 11.5,
              color: muteCol,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
