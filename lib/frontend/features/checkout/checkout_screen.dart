import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import 'package:orderacoffee/backend/services/paymongo_service.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/live_order_map.dart';
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
  PaymentMethod? _selectedPayment;
  CafeBranch _selectedBranch = kCafeBranches.first;
  LatLng _deliveryCoords = LocationService.defaultCustomerCoordinates;
  bool _applyLoyaltyDiscount = false;
  String _orderNote = '';
  final _addressController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  PaymentMethod get _effectivePayment {
    if (_selectedPayment != null) {
      if (_selectedType == OrderType.delivery &&
          _selectedPayment == PaymentMethod.counter) {
        return PaymentMethod.cash;
      }
      if (_selectedType != OrderType.delivery &&
          _selectedPayment == PaymentMethod.cash) {
        return PaymentMethod.counter;
      }
      return _selectedPayment!;
    }
    return _selectedType == OrderType.delivery
        ? PaymentMethod.cash
        : PaymentMethod.counter;
  }

  bool _isFormValid() {
    if (_selectedType == OrderType.delivery &&
        _addressController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  double _computeSubtotal(double cartTotal) => cartTotal;

  double _computeDeliveryFee(double subtotal) {
    if (_selectedType != OrderType.delivery) return 0.0;
    if (subtotal >= kFreeDeliveryThreshold) return 0.0;
    return LocationService.computeDeliveryFeeByDistance(
      _selectedBranch.coordinates,
      _deliveryCoords,
    );
  }

  double _computeDiscount(double subtotal, bool canRedeem) {
    if (!canRedeem || !_applyLoyaltyDiscount) return 0.0;
    return kLoyaltyRewardDiscount > subtotal
        ? subtotal
        : kLoyaltyRewardDiscount;
  }

  Future<void> _detectGpsLocation() async {
    final coords = await const LocationService().getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _deliveryCoords = coords;
      if (_addressController.text.trim().isEmpty) {
        _addressController.text =
            'Pinned Location (${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)})';
      }
      _validationError = null;
    });
  }

  Future<void> _promptOrderNote() async {
    String draftNote = _orderNote;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: draftNote);
        return AlertDialog(
          title: Text(
            'Order Note',
            style: GoogleFonts.figtree(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'E.g. Extra napkins, gate code, call upon arrival...',
            ),
            onChanged: (val) => draftNote = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save Note'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _orderNote = result;
      });
    }
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

    final authState = ref.read(authProvider);
    final user = authState.profile;
    final userId = user?.uid ?? '';
    final userName = user?.name ?? 'Customer';
    final userEmail = user?.email ?? '';

    final canRedeem =
        (user?.stamps ?? 0) >= 8 || authState.activeRewardCode != null;
    final subtotal = _computeSubtotal(cart.total);
    final deliveryFee = _computeDeliveryFee(subtotal);
    final discount = _computeDiscount(subtotal, canRedeem);
    final paymentMethod = _effectivePayment;

    String? rewardCode = authState.activeRewardCode;

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
      tableNo:
          _selectedType == OrderType.dineIn ? 'Dine-in (Open Seating)' : null,
      address: _selectedType == OrderType.delivery
          ? _addressController.text.trim()
          : null,
      payment: paymentMethod,
      note: _orderNote,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      rewardCode: discount > 0 ? (rewardCode ?? 'CAFEGO-8STAMPS') : null,
      branchId: _selectedBranch.id,
      branchName: _selectedBranch.name,
      branchLat: _selectedBranch.coordinates.latitude,
      branchLng: _selectedBranch.coordinates.longitude,
      deliveryLat: _selectedType == OrderType.delivery
          ? _deliveryCoords.latitude
          : null,
      deliveryLng: _selectedType == OrderType.delivery
          ? _deliveryCoords.longitude
          : null,
    );

    try {
      if (discount > 0) {
        if (authState.activeRewardCode == null && (user?.stamps ?? 0) >= 8) {
          await ref.read(authProvider.notifier).redeemStamps();
        }
        ref.read(authProvider.notifier).clearActiveRewardCode();
      }

      final orderId = await ref.read(ordersProvider.notifier).placeOrder(draft);
      await ref.read(authProvider.notifier).earnStamp();
      ref.read(cartProvider.notifier).clear();

      if (!mounted) return;

      if (paymentMethod == PaymentMethod.counter) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
        context.go('/order-receipt/$orderId');
        return;
      }

      final paymongoSession = ref.read(ordersProvider).lastPaymongoSession;
      if (paymentMethod.isPayMongo && paymongoSession != null) {
        await _showPayMongoAuthorizationSheet(
          orderId: orderId,
          session: paymongoSession,
          paymentMethod: paymentMethod,
          amount: draft.total,
        );
      }

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

  Future<void> _showPayMongoAuthorizationSheet({
    required String orderId,
    required PayMongoCheckoutSession session,
    required PaymentMethod paymentMethod,
    required double amount,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final cardBg = isDark ? AppColors.cardDark : Colors.white;
        final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
        final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
        final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.ok.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.ok,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Complete Payment',
                        style: GoogleFonts.figtree(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: inkCol,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close_rounded, color: muteCol),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Method',
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            color: muteCol,
                          ),
                        ),
                        Text(
                          paymentMethod.label,
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: inkCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Amount Due',
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            color: muteCol,
                          ),
                        ),
                        Text(
                          peso(amount),
                          style: GoogleFonts.figtree(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: inkCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Session ID: ${session.id}',
                      style: GoogleFonts.figtree(
                        fontSize: 11.5,
                        color: muteCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Checkout URL: ${session.checkoutUrl}',
                      style: GoogleFonts.figtree(
                        fontSize: 11,
                        color: muteCol,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Authorize payment now or allow your PayMongo webhook endpoint to mark this order as paid asynchronously.',
                style: GoogleFonts.figtree(
                  fontSize: 12.5,
                  color: muteCol,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              BrandButton(
                label: 'Authorize Payment Now',
                trailing: peso(amount),
                onPressed: () async {
                  await ref
                      .read(ordersProvider.notifier)
                      .completePayMongoPayment(orderId);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Await Webhook / Track Order (Pending)',
                    style: GoogleFonts.figtree(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: muteCol,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final authState = ref.watch(authProvider);
    final user = authState.profile;

    final paymentMethod = _effectivePayment;
    final paymentLabel = paymentMethod.label;

    final subtotal = _computeSubtotal(cart.total);
    final deliveryFee = _computeDeliveryFee(subtotal);
    final canRedeem =
        (user?.stamps ?? 0) >= 8 || authState.activeRewardCode != null;
    final discount = _computeDiscount(subtotal, canRedeem);
    final grandTotal =
        (subtotal + deliveryFee - discount).clamp(0.0, double.infinity);

    final needAddr = _selectedType == OrderType.delivery &&
        _addressController.text.trim().isEmpty;
    final canPlace = !needAddr && cart.lines.isNotEmpty;

    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;

    final availablePaymentMethods = _selectedType == OrderType.delivery
        ? const [
            PaymentMethod.cash,
            PaymentMethod.gcash,
            PaymentMethod.maya,
            PaymentMethod.card,
          ]
        : const [
            PaymentMethod.counter,
            PaymentMethod.gcash,
            PaymentMethod.maya,
            PaymentMethod.card,
          ];

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

            const SizedBox(height: 14),
            // CafeGO Branch Selector
            Text(
              'Select CafeGO Branch',
              style: GoogleFonts.figtree(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: muteCol,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kCafeBranches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final branch = kCafeBranches[index];
                  final isSelected = branch.id == _selectedBranch.id;
                  return ChoiceChip(
                    label: Text(
                      branch.name.replaceFirst('CafeGO ', ''),
                      style: GoogleFonts.figtree(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? cardBg : inkCol,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: inkCol,
                    backgroundColor: cardBg,
                    onSelected: (_) =>
                        setState(() => _selectedBranch = branch),
                  );
                },
              ),
            ),

            // Conditional Inputs
            if (_selectedType == OrderType.dineIn) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              if (user != null && user.addresses.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: user.addresses.map((addr) {
                    return ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 15),
                      label: Text(
                        '${addr.label}: ${addr.addressLine}',
                        style: GoogleFonts.figtree(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _addressController.text = addr.addressLine;
                          if (addr.lat != null && addr.lng != null) {
                            _deliveryCoords = LatLng(addr.lat!, addr.lng!);
                          }
                          _validationError = null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
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
              const SizedBox(height: 12),
              LiveOrderMap(
                height: 200,
                branchLocation: _selectedBranch.coordinates,
                branchName: _selectedBranch.name,
                customerLocation: _deliveryCoords,
                onLocationPicked: (latLng) {
                  setState(() {
                    _deliveryCoords = latLng;
                    if (_addressController.text.trim().isEmpty) {
                      _addressController.text =
                          'Pinned (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})';
                    }
                    _validationError = null;
                  });
                },
                onUseMyLocation: _detectGpsLocation,
              ),
            ],
            const SizedBox(height: 14),
            // Payment Info & PayMongo Selector Card
            Container(
              padding: const EdgeInsets.all(14),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availablePaymentMethods.map((method) {
                      final isSelected = paymentMethod == method;
                      return ChoiceChip(
                        label: Text(
                          method.label,
                          style: GoogleFonts.figtree(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? cardBg : inkCol,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: inkCol,
                        backgroundColor: cardBg,
                        onSelected: (_) =>
                            setState(() => _selectedPayment = method),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Loyalty Stamp Redemption Card
            if (user != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            'CafeGO Comfort Club (${user.stamps}/8 Stamps)',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                          ),
                          Text(
                            canRedeem
                                ? 'Redeem Free Drink Reward (-${peso(kLoyaltyRewardDiscount)})'
                                : 'Earn 1 stamp with this order!',
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              color: muteCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canRedeem)
                      Switch(
                        value: _applyLoyaltyDiscount,
                        onChanged: (val) =>
                            setState(() => _applyLoyaltyDiscount = val),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Order Note Trigger Button
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _promptOrderNote,
                icon: Icon(
                  _orderNote.isEmpty
                      ? Icons.note_add_outlined
                      : Icons.edit_note_rounded,
                  size: 18,
                  color: inkCol,
                ),
                label: Text(
                  _orderNote.isEmpty
                      ? 'Add order note'
                      : 'Note: $_orderNote',
                  style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: inkCol,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
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
                  ...cart.lines.map(
                    (line) => Padding(
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: lineCol),
                  const SizedBox(height: 6),
                  if (_selectedType == OrderType.delivery || discount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: GoogleFonts.figtree(
                            fontSize: 13.5,
                            color: muteCol,
                          ),
                        ),
                        Text(
                          peso(subtotal),
                          style: GoogleFonts.figtree(
                            fontSize: 13.5,
                            color: inkCol,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_selectedType == OrderType.delivery) ...[
                    Builder(
                      builder: (context) {
                        final km = LocationService.computeDistanceKm(
                          _selectedBranch.coordinates,
                          _deliveryCoords,
                        );
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivery (${km.toStringAsFixed(1)} km)',
                              style: GoogleFonts.figtree(
                                fontSize: 13.5,
                                color: muteCol,
                              ),
                            ),
                            Text(
                              deliveryFee == 0 ? 'FREE' : peso(deliveryFee),
                              style: GoogleFonts.figtree(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: deliveryFee == 0 ? AppColors.ok : inkCol,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (discount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Loyalty Discount',
                          style: GoogleFonts.figtree(
                            fontSize: 13.5,
                            color: AppColors.ok,
                          ),
                        ),
                        Text(
                          '- ${peso(discount)}',
                          style: GoogleFonts.figtree(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ok,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
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
                        peso(grandTotal),
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
              trailing: peso(grandTotal),
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
