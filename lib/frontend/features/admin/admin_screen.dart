import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/models/user_profile.dart';
import 'package:orderacoffee/backend/seed/seed_menu_data.dart';
import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/app_logo.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/order_card.dart';

import '../menu/menu_provider.dart';
import '../orders/orders_provider.dart';
import 'admin_provider.dart';
import 'widgets/admin_charts.dart';
import 'widgets/order_details_modal.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _selectedTabIndex = 0;
  String _orderStatusFilter = 'All';
  String _menuCatFilter = 'All';
  final _orderSearchController = TextEditingController();
  final _menuSearchController = TextEditingController();

  @override
  void dispose() {
    _orderSearchController.dispose();
    _menuSearchController.dispose();
    super.dispose();
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

  void _showMenuItemEditor({MenuItem? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.basePrice.toStringAsFixed(0) : '150',
    );
    final stockCtrl = TextEditingController(
      text: existing != null ? existing.stock.toString() : '50',
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
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF2B2220) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF2C2223);

            return AlertDialog(
              backgroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                existing == null ? 'Add New Product' : 'Edit Product',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Product Name'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: categories.contains(selectedCat) ? selectedCat : categories.first,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCat = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Base Price (₱)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Stock Units'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    // Picture Upload & Interactive Preview
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF3F3536) : const Color(0xFFF1E9E4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.lineDark : AppColors.lineLight),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imgCtrl.text.isNotEmpty
                              ? (imgCtrl.text.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(imgCtrl.text.split(',').last),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                                    )
                                  : Image.network(
                                      imgCtrl.text,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                                    ))
                              : Icon(Icons.photo_library_outlined, color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.upload_file_rounded, size: 18),
                                label: Text(imgCtrl.text.isNotEmpty ? 'Change Photo' : 'Upload Picture'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final xfile = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                    imageQuality: 85,
                                  );
                                  if (xfile != null) {
                                    final bytes = await xfile.readAsBytes();
                                    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                    setDialogState(() {
                                      imgCtrl.text = dataUrl;
                                    });
                                    try {
                                      final id = existing?.id ?? 'item_${DateTime.now().millisecondsSinceEpoch}';
                                      final url = await ref.read(menuRepositoryProvider).uploadPhoto(id, bytes);
                                      setDialogState(() {
                                        imgCtrl.text = url;
                                      });
                                    } catch (_) {}
                                  }
                                },
                              ),
                              if (imgCtrl.text.isNotEmpty)
                                TextButton(
                                  onPressed: () => setDialogState(() => imgCtrl.clear()),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 24),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: Colors.redAccent,
                                  ),
                                  child: const Text('Remove photo', style: TextStyle(fontSize: 11)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: imgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Or Image URL',
                        hintText: 'https://...',
                      ),
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
                    final price = double.tryParse(priceCtrl.text.trim()) ?? 150.0;
                    if (name.isEmpty) return;

                    final isCoffee = selectedCat == 'Hot Coffee' || selectedCat == 'Iced Coffee';
                    final item = MenuItem(
                      id: existing?.id ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      category: selectedCat,
                      description: descCtrl.text.trim(),
                      basePrice: price,
                      imageUrl: imgCtrl.text.trim().isEmpty ? null : imgCtrl.text.trim(),
                      isAvailable: existing?.isAvailable ?? true,
                      isHidden: existing?.isHidden ?? false,
                      options: existing?.options ?? (isCoffee ? defaultDrinkOptions : const MenuOptions()),
                      stock: int.tryParse(stockCtrl.text.trim()) ?? 50,
                    );

                    try {
                      if (existing == null) {
                        await ref.read(adminProvider).createMenuItem(item);
                      } else {
                        await ref.read(adminProvider).updateMenuItem(item);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Saved "${item.name}" successfully')),
                        );
                      }
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

  void _showDeleteConfirmDialog(MenuItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Product',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to remove "${item.name}" from the catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(adminProvider).deleteMenuItem(item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${item.name}"')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRoleChangeDialog(UserProfile user) {
    String currentRole = user.role;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Edit Role for ${user.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['customer', 'staff', 'admin'].map((role) {
                  final isSelected = currentRole == role;
                  return ListTile(
                    title: Text(role.toUpperCase()),
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFFD4A373) : Colors.grey,
                    ),
                    onTap: () {
                      setDialogState(() => currentRole = role);
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                BrandButton(
                  label: 'Update Role',
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(adminProvider).updateUserRole(user.uid, currentRole);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Updated ${user.name} to $currentRole')),
                      );
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    final isStoreOpen = ref.watch(storeStatusProvider);
    final queue = ref.watch(liveQueueStreamProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: bgCol,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: lineCol)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AdminTabPill(
                  icon: Icons.receipt_long_rounded,
                  label: 'Orders',
                  badgeCount: queue.length,
                  isSelected: _selectedTabIndex == 0,
                  selectedColor: brandCol,
                  unselectedColor: muteCol,
                  textColor: inkCol,
                  onTap: () => setState(() => _selectedTabIndex = 0),
                ),
                _AdminTabPill(
                  icon: Icons.coffee_rounded,
                  label: 'Catalog',
                  isSelected: _selectedTabIndex == 1,
                  selectedColor: brandCol,
                  unselectedColor: muteCol,
                  textColor: inkCol,
                  onTap: () => setState(() => _selectedTabIndex = 1),
                ),
                _AdminTabPill(
                  icon: Icons.insights_rounded,
                  label: 'Analytics',
                  isSelected: _selectedTabIndex == 2,
                  selectedColor: brandCol,
                  unselectedColor: muteCol,
                  textColor: inkCol,
                  onTap: () => setState(() => _selectedTabIndex = 2),
                ),
                _AdminTabPill(
                  icon: Icons.people_outline_rounded,
                  label: 'Staff/Users',
                  isSelected: _selectedTabIndex == 3,
                  selectedColor: brandCol,
                  unselectedColor: muteCol,
                  textColor: inkCol,
                  onTap: () => setState(() => _selectedTabIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Admin Header ──
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
                      color: const Color(0xFFD4A373).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD4A373).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, size: 12, color: Color(0xFFD4A373)),
                        const SizedBox(width: 4),
                        Text(
                          'ADMIN CONSOLE',
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: const Color(0xFFD4A373),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Store Open / Paused pill
                  InkWell(
                    onTap: () {
                      ref.read(adminProvider).toggleStoreStatus(!isStoreOpen);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStoreOpen
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isStoreOpen ? Colors.green : Colors.redAccent,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isStoreOpen ? Colors.green : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isStoreOpen ? 'Open' : 'Paused',
                            style: GoogleFonts.figtree(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isStoreOpen ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // "Store View" button
                  IconButton(
                    tooltip: 'View Customer Menu',
                    icon: Icon(Icons.storefront_outlined, size: 20, color: inkCol),
                    onPressed: () => context.go('/'),
                  ),
                  // Sign Out
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

            // ── Active Tab Body ──
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _buildOrdersTab(context, isDark, cardBg, lineCol, inkCol, muteCol, brandCol),
                  _buildCatalogTab(context, isDark, cardBg, lineCol, inkCol, muteCol, brandCol),
                  _buildAnalyticsTab(context, isDark, cardBg, lineCol, inkCol, muteCol),
                  _buildUsersTab(context, isDark, cardBg, lineCol, inkCol, muteCol, brandCol),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 1: ORDERS & KITCHEN QUEUE
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildOrdersTab(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color lineCol,
    Color inkCol,
    Color muteCol,
    Color brandCol,
  ) {
    final allOrders = ref.watch(allOrdersStreamProvider).valueOrNull ??
        ref.watch(liveQueueStreamProvider).valueOrNull ??
        [];

    final query = _orderSearchController.text.trim().toLowerCase();
    final filteredOrders = allOrders.where((order) {
      if (_orderStatusFilter != 'All' &&
          order.status.name.toLowerCase() != _orderStatusFilter.toLowerCase()) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesId = order.id.toLowerCase().contains(query);
        final matchesName = order.userName.toLowerCase().contains(query);
        if (!matchesId && !matchesName) return false;
      }
      return true;
    }).toList();

    const statusOptions = ['All', 'Received', 'Preparing', 'Ready', 'Completed', 'Cancelled'];

    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: TextField(
            controller: _orderSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search orders by ID or customer name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _orderSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _orderSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: lineCol),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: lineCol),
              ),
            ),
          ),
        ),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: statusOptions.map((st) {
              final isSel = _orderStatusFilter == st;
              final count = st == 'All'
                  ? allOrders.length
                  : allOrders.where((o) => o.status.name.toLowerCase() == st.toLowerCase()).length;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$st ($count)'),
                  selected: isSel,
                  onSelected: (selected) {
                    setState(() => _orderStatusFilter = st);
                  },
                  backgroundColor: cardBg,
                  selectedColor: brandCol.withValues(alpha: 0.18),
                  labelStyle: GoogleFonts.figtree(
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? brandCol : muteCol,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSel ? brandCol : lineCol),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Orders List
        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: muteCol),
                      const SizedBox(height: 12),
                      Text(
                        'No matching orders',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: inkCol,
                        ),
                      ),
                      Text(
                        'New customer orders will show up here automatically.',
                        style: GoogleFonts.figtree(color: muteCol, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final nextStatus = _getNextStatus(order.status);

                    return OrderCard(
                      order: order,
                      isStaffView: true,
                      onTap: () => OrderDetailsModal.show(context, order),
                      onAdvance: nextStatus != null
                          ? () async {
                              await ref.read(adminProvider).advanceOrder(order.id, nextStatus);
                              if (context.mounted) {
                                final label = kOrderLabels[nextStatus.name] ?? nextStatus.name;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Order ${order.id} is now ${label.toLowerCase()}')),
                                );
                              }
                            }
                          : null,
                      onCancel: (order.status == OrderStatus.received || order.status == OrderStatus.preparing)
                          ? () async {
                              await ref.read(adminProvider).cancelOrder(order.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Order ${order.id} cancelled')),
                                );
                              }
                            }
                          : null,
                      onUpdateRiderGps: (order.type == OrderType.delivery && order.status == OrderStatus.ready)
                          ? () async {
                              await ref.read(adminProvider).advanceRiderGps(order);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Updated rider GPS for ${order.id}')),
                                );
                              }
                            }
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 2: MENU & INVENTORY CATALOG
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildCatalogTab(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color lineCol,
    Color inkCol,
    Color muteCol,
    Color brandCol,
  ) {
    final menuItems = ref.watch(allMenuStreamProvider).valueOrNull ??
        ref.watch(menuStreamProvider).valueOrNull ??
        [];

    final query = _menuSearchController.text.trim().toLowerCase();
    final filteredItems = menuItems.where((item) {
      if (_menuCatFilter != 'All' && item.category != _menuCatFilter) return false;
      if (query.isNotEmpty) {
        if (!item.name.toLowerCase().contains(query) &&
            !item.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    const categories = ['All', 'Hot Coffee', 'Iced Coffee', 'Non-Coffee', 'Pastries', 'Merch'];

    return Column(
      children: [
        // Action Bar: Search & "Add Product" button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _menuSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _menuSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _menuSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: lineCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: lineCol),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                key: const Key('adminAddProductButton'),
                onPressed: () => _showMenuItemEditor(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandCol,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),

        // Category Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: categories.map((cat) {
              final isSel = _menuCatFilter == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (selected) => setState(() => _menuCatFilter = cat),
                  backgroundColor: cardBg,
                  selectedColor: brandCol.withValues(alpha: 0.18),
                  labelStyle: GoogleFonts.figtree(
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? brandCol : muteCol,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSel ? brandCol : lineCol),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Product Cards List
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text(
                    'No menu products found',
                    style: GoogleFonts.figtree(color: muteCol),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: lineCol),
                      ),
                      child: Row(
                        children: [
                          // Item Thumbnail
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF3F3536) : const Color(0xFFF1E9E4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                ? Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.coffee_rounded,
                                      size: 26,
                                      color: brandCol,
                                    ),
                                  )
                                : Icon(Icons.coffee_rounded, size: 26, color: brandCol),
                          ),
                          const SizedBox(width: 14),

                          // Item Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: GoogleFonts.figtree(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: inkCol,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isHidden)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Hidden',
                                          style: GoogleFonts.figtree(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.amber[800],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.category} • ${peso(item.basePrice)}',
                                  style: GoogleFonts.figtree(fontSize: 13, color: muteCol),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      'Stock: ${item.stock}',
                                      style: GoogleFonts.figtree(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: item.stock < 5 ? Colors.redAccent : brandCol,
                                      ),
                                    ),
                                    if (item.stock < 5) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Low (<5)',
                                          style: GoogleFonts.figtree(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () async {
                                        if (item.stock > 0) {
                                          await ref.read(adminProvider).updateItemStock(item.id, item.stock - 1);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: lineCol),
                                        ),
                                        child: Icon(Icons.remove, size: 12, color: muteCol),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () async {
                                        await ref.read(adminProvider).updateItemStock(item.id, item.stock + 1);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: lineCol),
                                        ),
                                        child: Icon(Icons.add, size: 12, color: muteCol),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Edit & Delete actions
                          IconButton(
                            tooltip: 'Edit product',
                            icon: Icon(Icons.edit_outlined, size: 18, color: muteCol),
                            onPressed: () => _showMenuItemEditor(existing: item),
                          ),
                          IconButton(
                            tooltip: 'Delete product',
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            onPressed: () => _showDeleteConfirmDialog(item),
                          ),

                          // Availability Switch
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch.adaptive(
                                value: item.isAvailable,
                                activeTrackColor: AppColors.ok,
                                onChanged: (val) async {
                                  await ref.read(adminProvider).toggleItemAvailability(item.id, val);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          val ? '${item.name} is now Available' : '${item.name} marked as Sold Out',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                              ),
                              Text(
                                item.isAvailable ? 'In Stock' : 'Sold Out',
                                style: GoogleFonts.figtree(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: item.isAvailable ? AppColors.ok : Colors.redAccent,
                                ),
                              ),
                            ],
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

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 3: BUSINESS & SALES ANALYTICS
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyticsTab(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color lineCol,
    Color inkCol,
    Color muteCol,
  ) {
    final completedToday = ref.watch(completedTodayProvider).valueOrNull ?? [];
    final queue = ref.watch(liveQueueStreamProvider).valueOrNull ?? [];
    final topSelling = ref.watch(topSellingItemsProvider).valueOrNull ?? [];

    final todayRevenue = completedToday.fold<double>(0.0, (sum, o) => sum + o.total);
    final aov = completedToday.isNotEmpty ? todayRevenue / completedToday.length : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Financial Overview',
          style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: inkCol),
        ),
        const SizedBox(height: 12),

        // 4 KPI Cards Grid
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: "Today's Revenue",
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
                label: 'Average Order Value',
                value: peso(aov),
                subtitle: 'AOV per ticket',
                cardBg: cardBg,
                lineCol: lineCol,
                inkCol: inkCol,
                muteCol: muteCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Active in Queue',
                value: '${queue.length}',
                subtitle: 'Pending fulfillment',
                cardBg: cardBg,
                lineCol: lineCol,
                inkCol: inkCol,
                muteCol: muteCol,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Completed Orders',
                value: '${completedToday.length}',
                subtitle: 'Dispatched today',
                cardBg: cardBg,
                lineCol: lineCol,
                inkCol: inkCol,
                muteCol: muteCol,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Real-Time Dashboard Analytics Graphs ──
        AdminSalesChart(orders: [...completedToday, ...queue]),
        const SizedBox(height: 14),
        AdminCategoryDistributionChart(orders: [...completedToday, ...queue]),
        const SizedBox(height: 14),
        AdminOrderStatusDistributionChart(orders: [...completedToday, ...queue]),

        const SizedBox(height: 24),

        // Top Selling Products Section
        Text(
          'Top Selling Items',
          style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: inkCol),
        ),
        const SizedBox(height: 12),

        if (topSelling.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lineCol),
            ),
            child: Center(
              child: Text(
                'Complete customer orders to view real-time sales leaderboards.',
                style: GoogleFonts.figtree(color: muteCol),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lineCol),
            ),
            child: Column(
              children: topSelling.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == topSelling.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(bottom: BorderSide(color: lineCol)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? const Color(0xFFD4A373)
                              : (isDark ? const Color(0xFF3F3536) : const Color(0xFFE5DDD8)),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: index == 0 ? Colors.white : inkCol,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String? ?? 'Product',
                              style: GoogleFonts.figtree(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: inkCol,
                              ),
                            ),
                            Text(
                              '${item['qty']} sold',
                              style: GoogleFonts.figtree(fontSize: 12, color: muteCol),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        peso((item['revenue'] as num?)?.toDouble() ?? 0.0),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: inkCol,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TAB 4: USERS & STAFF MANAGEMENT
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildUsersTab(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color lineCol,
    Color inkCol,
    Color muteCol,
    Color brandCol,
  ) {
    final users = ref.watch(allUsersStreamProvider).valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Accounts & Staff Directory',
              style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: inkCol),
            ),
            Text(
              '${users.length} registered',
              style: GoogleFonts.figtree(fontSize: 12, color: muteCol),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (users.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Loading user accounts...', style: GoogleFonts.figtree(color: muteCol)),
            ),
          )
        else
          ...users.map((user) {
            final isAdmin = user.role == 'admin';
            final isStaff = user.role == 'staff';

            Color badgeBg;
            Color badgeText;
            if (isAdmin) {
              badgeBg = const Color(0xFFD4A373).withValues(alpha: 0.2);
              badgeText = const Color(0xFFD4A373);
            } else if (isStaff) {
              badgeBg = Colors.blue.withValues(alpha: 0.2);
              badgeText = Colors.blueAccent;
            } else {
              badgeBg = Colors.grey.withValues(alpha: 0.2);
              badgeText = muteCol;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lineCol),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark ? const Color(0xFF3F3536) : const Color(0xFFE5DDD8),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: GoogleFonts.playfairDisplay(
                        fontWeight: FontWeight.bold,
                        color: brandCol,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.name,
                              style: GoogleFonts.figtree(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: inkCol,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: GoogleFonts.figtree(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: GoogleFonts.figtree(fontSize: 12, color: muteCol),
                        ),
                        if (user.phone.isNotEmpty)
                          Text(
                            user.phone,
                            style: GoogleFonts.figtree(fontSize: 11, color: muteCol),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Change role',
                    icon: Icon(Icons.manage_accounts_outlined, size: 20, color: muteCol),
                    onPressed: () => _showRoleChangeDialog(user),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ── Segmented Tab Pill ───────────────────────────────────────────────────────
class _AdminTabPill extends StatelessWidget {
  const _AdminTabPill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.textColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final Color textColor;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                backgroundColor: AppColors.brandDark,
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.figtree(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? textColor : unselectedColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Metric KPI Card ─────────────────────────────────────────────────────────
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
