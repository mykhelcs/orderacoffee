import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/orders/orders_provider.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/app_logo.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/status_badge.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _selectedFilter = 'All';
  Timer? _prepTicker;

  @override
  void initState() {
    super.initState();
    // 1-second ticker to update elapsed prep timers smoothly in real time
    _prepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _prepTicker?.cancel();
    super.dispose();
  }

  String _formatElapsedTime(DateTime? createdAt) {
    if (createdAt == null) return '00:00';
    final diff = DateTime.now().difference(createdAt);
    if (diff.isNegative) return '00:00';
    final mins = diff.inMinutes.toString().padLeft(2, '0');
    final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _advanceOrderStatus(
    BuildContext context,
    String orderId,
    OrderStatus next,
  ) async {
    try {
      await ref.read(orderRepositoryProvider).advanceStatus(orderId, next);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  void _showCashierDrawer(BuildContext context, Order order) {
    final total = order.total;
    final cashCtrl = TextEditingController(text: total.toStringAsFixed(0));
    double cashReceived = total;
    double change = 0.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
            final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
            final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
            final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

            void updateCash(double val) {
              setSheetState(() {
                cashReceived = val;
                cashCtrl.text = val.toStringAsFixed(0);
                change = cashReceived >= total ? cashReceived - total : 0.0;
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: lineCol),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: lineCol,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cash Register / Payment',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: inkCol,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      'Customer: ${order.userName.isNotEmpty ? order.userName : 'Customer'} • Method: ${order.payment.label}',
                      style: GoogleFonts.figtree(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Total Due Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: brandCol.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount Due',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                          ),
                          Text(
                            peso(total),
                            style: GoogleFonts.figtree(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: brandCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Cash Chips
                    Row(
                      children: [
                        ActionChip(
                          label: const Text('Exact'),
                          onPressed: () => updateCash(total),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('₱500'),
                          onPressed: () => updateCash(500.0),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('₱1,000'),
                          onPressed: () => updateCash(1000.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount Received Field
                    TextField(
                      controller: cashCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cash Tendered / Amount Received (₱)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0.0;
                        setSheetState(() {
                          cashReceived = parsed;
                          change = cashReceived >= total ? cashReceived - total : 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Change Calculation Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: change > 0
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change to Return',
                            style: GoogleFonts.figtree(
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                          ),
                          Text(
                            peso(change),
                            style: GoogleFonts.figtree(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: change > 0 ? Colors.green[700] : inkCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    BrandButton(
                      label: 'Confirm Cash Receipt',
                      onPressed: cashReceived >= total
                          ? () async {
                              Navigator.pop(ctx);
                              final staffUid = ref.read(authProvider).profile?.uid;
                              try {
                                await ref.read(orderRepositoryProvider).markPaymentPaid(
                                      order.id,
                                      handledBy: staffUid,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Payment recorded! Change: ${peso(change)}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to record payment: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    ).whenComplete(cashCtrl.dispose);
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

    final allOrders = ref.watch(liveQueueStreamProvider).valueOrNull ?? [];

    // Filter orders
    final queue = allOrders.where((o) {
      if (_selectedFilter == 'All') return true;
      return o.status.name.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    // FIFO sort: oldest first
    queue.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

    final receivedCount = allOrders.where((o) => o.status == OrderStatus.received).length;
    final preparingCount = allOrders.where((o) => o.status == OrderStatus.preparing).length;
    final readyCount = allOrders.where((o) => o.status == OrderStatus.ready).length;

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
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
                      color: brandCol.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: brandCol.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.coffee_maker_rounded, size: 12, color: Color(0xFFD4A373)),
                        const SizedBox(width: 4),
                        Text(
                          'KITCHEN QUEUE (KDS)',
                          style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: brandCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
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

            // ── Stats Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildStatPill('Received', receivedCount, const Color(0xFFD4A373), 'received'),
                  const SizedBox(width: 8),
                  _buildStatPill('Preparing', preparingCount, const Color(0xFFE29578), 'preparing'),
                  const SizedBox(width: 8),
                  _buildStatPill('Ready', readyCount, const Color(0xFF2A9D8F), 'ready'),
                  const SizedBox(width: 8),
                  _buildStatPill('All Queue', allOrders.length, brandCol, 'All'),
                ],
              ),
            ),

            // ── Queue Tickets List ──
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.done_all_rounded, size: 48, color: brandCol),
                          const SizedBox(height: 12),
                          Text(
                            'All Orders Cleared!',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                          ),
                          Text(
                            'New customer orders will ring here automatically.',
                            style: GoogleFonts.figtree(color: muteCol, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final order = queue[index];
                        final elapsed = _formatElapsedTime(order.createdAt);
                        final isUnpaid = order.paymentStatus != PaymentStatus.paid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: order.status == OrderStatus.received
                                  ? const Color(0xFFD4A373)
                                  : lineCol,
                              width: order.status == OrderStatus.received ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ticket Header: Customer + Prep Timer + Status Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      order.userName.isNotEmpty ? order.userName : 'Customer',
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: inkCol,
                                      ),
                                    ),
                                  ),
                                  // Live Timer Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 13, color: Colors.redAccent),
                                        const SizedBox(width: 4),
                                        Text(
                                          elapsed,
                                          style: GoogleFonts.figtree(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: order.status),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Order Type & Payment Info
                              Text(
                                '${order.type == OrderType.dineIn ? 'Dine-In • Table ${order.tableNo ?? '-'}' : order.type == OrderType.delivery ? 'Delivery' : 'Pickup'} • ${order.payment.label} (${order.paymentStatus.name.toUpperCase()}) • ${peso(order.total)}',
                                style: GoogleFonts.figtree(fontSize: 12.5, color: muteCol),
                              ),
                              const Divider(height: 16),

                              // Items List with Full Customizations
                              ...order.items.map((item) {
                                final custom = item.customizationSummary;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.qty}x ${item.name}',
                                        style: GoogleFonts.figtree(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: inkCol,
                                        ),
                                      ),
                                      if (custom.isNotEmpty)
                                        Text(
                                          custom,
                                          style: GoogleFonts.figtree(fontSize: 12, color: muteCol),
                                        ),
                                      if (item.note.isNotEmpty)
                                        Text(
                                          'Note: ${item.note}',
                                          style: GoogleFonts.figtree(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.crema,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),

                              if ((order.note ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Special Instruction: ${order.note}',
                                    style: GoogleFonts.figtree(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: inkCol,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Contextual Action Buttons
                              Row(
                                children: [
                                  if (order.status == OrderStatus.received)
                                    Expanded(
                                      child: BrandButton(
                                        label: 'Start Preparing',
                                        onPressed: () => _advanceOrderStatus(
                                          context,
                                          order.id,
                                          OrderStatus.preparing,
                                        ),
                                      ),
                                    ),
                                  if (order.status == OrderStatus.preparing)
                                    Expanded(
                                      child: BrandButton(
                                        label: 'Mark as Ready',
                                        onPressed: () => _advanceOrderStatus(
                                          context,
                                          order.id,
                                          OrderStatus.ready,
                                        ),
                                      ),
                                    ),
                                  if (order.status == OrderStatus.ready)
                                    Expanded(
                                      child: BrandButton(
                                        label: 'Mark as Handed Off',
                                        onPressed: () => _advanceOrderStatus(
                                          context,
                                          order.id,
                                          OrderStatus.completed,
                                        ),
                                      ),
                                    ),
                                  if (isUnpaid) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GhostButton(
                                        label: 'Receive Cash',
                                        icon: Icons.point_of_sale_rounded,
                                        onPressed: () => _showCashierDrawer(context, order),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, int count, Color col, String filterKey) {
    final isSel = _selectedFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = filterKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? col.withValues(alpha: 0.18) : col.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? col : col.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: GoogleFonts.figtree(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: col,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.figtree(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: col,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
