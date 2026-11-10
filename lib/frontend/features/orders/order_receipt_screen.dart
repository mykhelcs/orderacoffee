import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'orders_provider.dart';

class OrderReceiptScreen extends ConsumerWidget {
  final String orderId;

  const OrderReceiptScreen({
    required this.orderId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(singleOrderStreamProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Receipt'),
        centerTitle: true,
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(
              child: Text(
                'Order not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            );
          }
          final dateStr = order.createdAt != null
              ? DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt!)
              : '';
          final subtotalVal = order.subtotal ?? order.computedSubtotal;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID & Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${order.status.name.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          color: _getStatusColor(order.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ordered on: $dateStr',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Items Section
                Text(
                  'Items',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'x${item.qty}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Pricing Summary
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text('₱${subtotalVal.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
                if (order.deliveryFee > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee:'),
                        Text('₱${order.deliveryFee.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                if (order.discount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:'),
                        Text('-₱${order.discount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '₱${order.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.brown.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Branch Info
                if (order.branchName != null || order.branchId != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.branchName ?? order.branchId ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/orders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading order: $err'),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.received:
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.ready:
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}
