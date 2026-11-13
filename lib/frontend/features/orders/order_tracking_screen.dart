import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/backend/services/location_service.dart';
import 'package:orderacoffee/frontend/features/auth/auth_provider.dart';
import 'package:orderacoffee/frontend/features/menu/menu_provider.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'package:orderacoffee/frontend/widgets/cup_icon.dart';
import 'package:orderacoffee/frontend/widgets/ghost_button.dart';
import 'package:orderacoffee/frontend/widgets/live_order_map.dart';
import 'package:orderacoffee/frontend/widgets/scooter_delivery_graphic.dart';
import 'orders_provider.dart';
import 'rating_provider.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool _ratingShown = false;

  String _formatOrderCode(String id) {
    if (id.isEmpty) return 'Order #BB2456';
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = clean.length >= 4
        ? clean.substring(clean.length - 4).toUpperCase()
        : clean.toUpperCase().padLeft(4, '0');
    return 'Order #BB$suffix';
  }

  Future<void> _checkAndShowRatingSheet(Order order) async {
    final user = ref.read(authProvider).profile;
    if (user == null) return;
    try {
      final hasRated = await ref.read(ratingRepositoryProvider).hasRated(
            orderId: order.id,
            userId: user.uid,
          );
      if (!hasRated && mounted) {
        _showRatingBottomSheet(order, user.uid);
      }
    } catch (_) {}
  }

  void _showRatingBottomSheet(Order order, String userId) {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final cardBg = isDark ? AppColors.cardDark : Colors.white;
            final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
            final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: muteCol.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How was your order?',
                    style: GoogleFonts.figtree(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: inkCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rate your CafeGO coffee experience',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: muteCol,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        iconSize: 38,
                        icon: Icon(
                          starValue <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFD49755),
                        ),
                        onPressed: () {
                          setSheetState(() {
                            selectedRating = starValue;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add an optional comment...',
                      hintStyle:
                          GoogleFonts.figtree(fontSize: 14, color: muteCol),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: muteCol.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: muteCol.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  BrandButton(
                    label: 'Submit Review',
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(ratingRepositoryProvider).submitRating(
                              orderId: order.id,
                              userId: userId,
                              rating: selectedRating.toDouble(),
                              review: commentController.text.trim().isNotEmpty
                                  ? commentController.text.trim()
                                  : null,
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanks for rating!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to submit rating: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(commentController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCanvas =
        isDark ? const Color(0xFF1E1919) : const Color(0xFFFAF7F2);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final lineCol = isDark ? AppColors.lineDark : const Color(0xFFE8DFD5);
    final inkCol = isDark ? AppColors.inkDark : const Color(0xFF1B120C);
    final muteCol = isDark ? AppColors.muteDark : const Color(0xFF7A6D65);
    final brownAccent =
        isDark ? const Color(0xFFD4A373) : const Color(0xFF3B2314);
    final lightStepBg =
        isDark ? const Color(0xFF2E2425) : const Color(0xFFD9D4CC);

    ref.listen<AsyncValue<Order?>>(
        singleOrderStreamProvider(widget.orderId), (prev, next) {
      final order = next.valueOrNull;
      if (order != null &&
          order.status == OrderStatus.completed &&
          !_ratingShown) {
        _ratingShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowRatingSheet(order);
        });
      }
    });

    final orderAsync = ref.watch(singleOrderStreamProvider(widget.orderId));
    final menuItems = ref.watch(menuStreamProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: bgCanvas,
      body: orderAsync.when(
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

          int activeStepIndex = 2; // Default to 'On the way'
          if (order.status == OrderStatus.received) {
            activeStepIndex = 0;
          } else if (order.status == OrderStatus.preparing) {
            activeStepIndex = 1;
          } else if (order.status == OrderStatus.ready) {
            activeStepIndex = 2;
          } else if (order.status == OrderStatus.completed) {
            activeStepIndex = 3;
          } else if (order.status == OrderStatus.cancelled) {
            activeStepIndex = -1;
          }

          final branchCoords =
              (order.branchLat != null && order.branchLng != null)
                  ? LatLng(order.branchLat!, order.branchLng!)
                  : LocationService.defaultBranch.coordinates;

          final customerCoords =
              (order.deliveryLat != null && order.deliveryLng != null)
                  ? LatLng(order.deliveryLat!, order.deliveryLng!)
                  : (order.type == OrderType.delivery
                      ? LocationService.defaultCustomerCoordinates
                      : null);

          final riderCoords = (order.riderLat != null && order.riderLng != null)
              ? LatLng(order.riderLat!, order.riderLng!)
              : (order.status == OrderStatus.ready && customerCoords != null
                  ? LocationService.interpolateLocation(
                      branchCoords,
                      customerCoords,
                      0.5,
                    )
                  : null);

          return Stack(
            children: [
              // Full-Screen Map (Positioned.fill)
              Positioned.fill(
                child: LiveOrderMap(
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                  branchLocation: branchCoords,
                  branchName:
                      order.branchName ?? LocationService.defaultBranch.name,
                  customerLocation: customerCoords,
                  riderLocation: riderCoords,
                  showRider: order.type == OrderType.delivery &&
                      (order.status == OrderStatus.ready ||
                          order.riderLat != null),
                ),
              ),

              // Draggable Bottom Sheet with Order Tracking Details
              DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.15,
                maxChildSize: 0.90,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: bgCanvas,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: muteCol.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),

                        // Order Number & Payment Status Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatOrderCode(order.id),
                              style: GoogleFonts.figtree(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: inkCol,
                              ),
                            ),
                            _PaymentStatusBadge(order: order),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (order.status == OrderStatus.cancelled) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.bad.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.bad.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cancel_outlined,
                                  color: AppColors.bad,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This order has been cancelled.',
                                    style: GoogleFonts.figtree(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.bad,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // GCash / PayMongo QR Code Card + PAY Button
                        if (order.payment.isPayMongo &&
                            order.paymentStatus == PaymentStatus.pending &&
                            order.status != OrderStatus.cancelled) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.warn.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.qr_code_2_rounded,
                                      color: AppColors.warn,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Scan QR to Pay via ${order.payment.label}',
                                      style: GoogleFonts.figtree(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: inkCol,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: QrImageView(
                                    data: (order.paymongoCheckoutUrl != null &&
                                            order.paymongoCheckoutUrl!
                                                .isNotEmpty)
                                        ? order.paymongoCheckoutUrl!
                                        : 'https://checkout.paymongo.com/${order.id}',
                                    version: QrVersions.auto,
                                    size: 180.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Or authorize payment directly:',
                                  style: GoogleFonts.figtree(
                                    fontSize: 12,
                                    color: muteCol,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                BrandButton(
                                  label: 'PAY',
                                  trailing: peso(order.total),
                                  onPressed: () {
                                    ref
                                        .read(ordersProvider.notifier)
                                        .completePayMongoPayment(order.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

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

                        // Scooter Courier Graphic
                        const ScooterDeliveryGraphic(),

                        const SizedBox(height: 6),

                        // 4-Stage Horizontal Status Stepper
                        _buildHorizontalStepper(
                          activeStepIndex: activeStepIndex,
                          brownAccent: brownAccent,
                          lightStepBg: lightStepBg,
                          inkCol: inkCol,
                          muteCol: muteCol,
                        ),

                        if (order.status == OrderStatus.received) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(ordersProvider.notifier)
                                      .cancelOrder(order.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Order cancelled.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Unable to cancel order: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.cancel_outlined,
                                size: 16,
                                color: AppColors.bad,
                              ),
                              label: Text(
                                'Cancel Order',
                                style: GoogleFonts.figtree(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.bad,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Order Details Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: lineCol.withValues(alpha: 0.6),
                            ),
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
                              if (order.address != null &&
                                  order.address!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Deliver to: ${order.address}',
                                  style: GoogleFonts.figtree(
                                    fontSize: 12.5,
                                    color: muteCol,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // List of items
                              ...order.items.map((item) {
                                final match = menuItems
                                    .where(
                                      (m) =>
                                          m.name.toLowerCase() ==
                                              item.name.toLowerCase() ||
                                          m.id == item.itemId,
                                    )
                                    .firstOrNull;
                                final imgUrl = match?.imageUrl;
                                final customSummary = item.customizationSummary;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5EFE6),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: (imgUrl != null &&
                                                imgUrl.isNotEmpty)
                                            ? Image.network(
                                                imgUrl,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Center(
                                                  child: CupIcon(
                                                    size: 24,
                                                    color: Color(0xFF5A3825),
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: CupIcon(
                                                  size: 24,
                                                  color: Color(0xFF5A3825),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item.qty} x ${item.name}',
                                              style: GoogleFonts.figtree(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: inkCol,
                                              ),
                                            ),
                                            if (customSummary.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Text(
                                                  customSummary,
                                                  style: GoogleFonts.figtree(
                                                    fontSize: 12,
                                                    color: muteCol,
                                                  ),
                                                ),
                                              ),
                                            if (item.note.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Text(
                                                  'Note: ${item.note}',
                                                  style: GoogleFonts.figtree(
                                                    fontSize: 11.5,
                                                    fontStyle: FontStyle.italic,
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

                              if (order.deliveryFee > 0 ||
                                  order.discount > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal',
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        color: muteCol,
                                      ),
                                    ),
                                    Text(
                                      peso(order.computedSubtotal),
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        color: inkCol,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (order.deliveryFee > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Delivery Fee',
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        color: muteCol,
                                      ),
                                    ),
                                    Text(
                                      peso(order.deliveryFee),
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        color: inkCol,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (order.discount > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Loyalty Discount',
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        color: AppColors.ok,
                                      ),
                                    ),
                                    Text(
                                      '- ${peso(order.discount)}',
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ok,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],

                              // Total Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                );
                },
              ),

              // Floating Blurred Top App Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: (isDark
                              ? const Color(0xFF1E1919)
                              : const Color(0xFFFAF7F2))
                          .withValues(alpha: 0.8),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.of(context).padding.top + 8,
                        16,
                        12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: inkCol,
                              size: 24,
                            ),
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
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: inkCol,
                              size: 24,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Order ref: ${order.id}')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
        Stack(
          alignment: Alignment.center,
          children: [
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
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
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

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final isPaid = order.paymentStatus == PaymentStatus.paid;
    final isPending = order.paymentStatus == PaymentStatus.pending;

    final bgColor = isPaid
        ? AppColors.ok.withValues(alpha: 0.14)
        : isPending
            ? AppColors.warn.withValues(alpha: 0.15)
            : AppColors.crema.withValues(alpha: 0.15);
    final fgColor = isPaid
        ? AppColors.ok
        : isPending
            ? AppColors.warn
            : AppColors.crema;

    final statusText = isPaid
        ? 'PAID • ${order.payment.label}'
        : isPending
            ? 'PENDING • ${order.payment.label}'
            : order.payment.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.figtree(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fgColor,
        ),
      ),
    );
  }
}
