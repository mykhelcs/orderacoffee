import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import '../orders/orders_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  OrderType _selectedType = OrderType.pickup;
  final _addressController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    if (_selectedType == OrderType.delivery && _addressController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _handlePlaceOrder() async {
    if (!_isFormValid()) {
      setState(() {
        _validationError = 'Enter a delivery address to continue.';
      });
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart.lines.isEmpty) return;

    final user = ref.read(authProvider).profile;
    final userId = user?.uid ?? '';
    final userName = user?.name ?? 'Customer';
    final userEmail = user?.email ?? '';

    final paymentMethod = _selectedType == OrderType.delivery
        ? PaymentMethod.cash
        : PaymentMethod.counter;

    final orderItems = cart.lines.map((line) {
      return OrderItem(
        itemId: line.itemId,
        name: line.name,
        customizations: line.customizations.toMap(),
        qty: line.qty,
        unitPrice: line.unitPrice,
        note: line.note,
      );
    }).toList();

    final draft = OrderDraft(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      items: orderItems,
      type: _selectedType,
      tableNo: _selectedType == OrderType.dineIn ? 'Dine-in (Open Seating)' : null,
      address: _selectedType == OrderType.delivery ? _addressController.text.trim() : null,
      payment: paymentMethod,
    );

    try {
      final orderId = await ref.read(ordersProvider.notifier).placeOrder(draft);
      ref.read(cartProvider.notifier).clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
        context.go('/order/$orderId');
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('permission-denied') ||
                e.toString().contains('PERMISSION_DENIED')
            ? 'Firestore permission denied. Update Firebase Security Rules for orders.'
            : 'Failed to place order: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent.shade700,
          ),
        );
      }
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

    final cart = ref.watch(cartProvider);
    final ordersState = ref.watch(ordersProvider);

    final paymentLabel = _selectedType == OrderType.delivery
        ? 'Cash on delivery'
        : 'Pay at counter';

    final needAddr = _selectedType == OrderType.delivery && _addressController.text.trim().isEmpty;
    final canPlace = !needAddr && cart.lines.isNotEmpty;

    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bgCol,
      body: SafeArea(
        child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Row(
          children: [
            GhostButton(
              label: 'Back to cart',
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.go('/cart'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Checkout',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: inkCol,
          ),
        ),
        const SizedBox(height: 14),
        // Order Type Segmented Control
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: lineCol),
          ),
          child: Row(
            children: [
              _OrderTypeSegment(
                label: 'Pickup',
                isSelected: _selectedType == OrderType.pickup,
                onTap: () => setState(() {
                  _selectedType = OrderType.pickup;
                  _validationError = null;
                }),
              ),
              _OrderTypeSegment(
                label: 'Dine-in',
                isSelected: _selectedType == OrderType.dineIn,
                onTap: () => setState(() {
                  _selectedType = OrderType.dineIn;
                  _validationError = null;
                }),
              ),
              _OrderTypeSegment(
                label: 'Delivery',
                isSelected: _selectedType == OrderType.delivery,
                onTap: () => setState(() {
                  _selectedType = OrderType.delivery;
                  _validationError = null;
                }),
              ),
            ],
          ),
        ),
        // Conditional Inputs
        if (_selectedType == OrderType.dineIn) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: lineCol),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_restaurant_outlined,
                  size: 22,
                  color: AppColors.crema,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dine-in Service',
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: inkCol,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Grab any comfortable seat. Your order will be served to you or your number will be called.',
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          color: muteCol,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_selectedType == OrderType.delivery) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _validationError = null),
            decoration: const InputDecoration(
              hintText: 'Delivery address (Street, Unit / House No.)',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Payment Info Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lineCol),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment',
                style: GoogleFonts.figtree(
                  fontSize: 15,
                  color: muteCol,
                ),
              ),
              Text(
                paymentLabel,
                style: GoogleFonts.figtree(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: inkCol,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Order Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lineCol),
          ),
          child: Column(
            children: [
              ...cart.lines.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${line.qty}x ${line.name}',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              color: inkCol,
                            ),
                          ),
                        ),
                        Text(
                          peso(line.lineTotal),
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: inkCol,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 8),
              Divider(color: lineCol),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.figtree(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: inkCol,
                    ),
                  ),
                  Text(
                    peso(cart.total),
                    style: GoogleFonts.figtree(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: inkCol,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 10),
          Text(
            _validationError!,
            style: GoogleFonts.figtree(
              color: AppColors.bad,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 18),
        BrandButton(
          label: 'Place order',
          trailing: peso(cart.total),
          isLoading: ordersState.isPlacingOrder,
          onPressed: canPlace ? _handlePlaceOrder : null,
        ),
        const SizedBox(height: 20),
      ],
    ),
      ),
    );
  }
}

class _OrderTypeSegment extends StatelessWidget {
  const _OrderTypeSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Expanded(
      child: Material(
        color: isSelected ? inkCol : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.figtree(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? cardBg : inkCol,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
