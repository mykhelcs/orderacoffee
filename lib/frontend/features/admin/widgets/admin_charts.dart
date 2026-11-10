import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orderacoffee/backend/models/order.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';

class AdminSalesChart extends StatelessWidget {
  const AdminSalesChart({
    super.key,
    required this.orders,
  });

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    // Aggregate orders by time window or days
    // Let's create 6 time buckets (e.g., 8am-10am, 10am-12pm, 12pm-2pm, 2pm-4pm, 4pm-6pm, 6pm-8pm)
    final buckets = [
      ('8-10 AM', 0.0, 0),
      ('10-12 PM', 0.0, 0),
      ('12-2 PM', 0.0, 0),
      ('2-4 PM', 0.0, 0),
      ('4-6 PM', 0.0, 0),
      ('6-8 PM', 0.0, 0),
    ];

    double maxVal = 100.0;

    for (final order in orders) {
      final hour = order.createdAt?.hour ?? DateTime.now().hour;
      int idx = 0;
      if (hour < 10) {
        idx = 0;
      } else if (hour < 12) {
        idx = 1;
      } else if (hour < 14) {
        idx = 2;
      } else if (hour < 16) {
        idx = 3;
      } else if (hour < 18) {
        idx = 4;
      } else {
        idx = 5;
      }

      final current = buckets[idx];
      buckets[idx] = (
        current.$1,
        current.$2 + order.total,
        current.$3 + 1,
      );
      if (buckets[idx].$2 > maxVal) {
        maxVal = buckets[idx].$2;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                'Hourly Revenue & Demand',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: inkCol,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: brandCol.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Today',
                  style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: brandCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Bar Chart Canvas
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((b) {
                final heightFactor = (b.$2 / maxVal).clamp(0.06, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (b.$2 > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '₱${b.$2.toStringAsFixed(0)}',
                              style: GoogleFonts.figtree(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: brandCol,
                              ),
                            ),
                          ),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: heightFactor,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    brandCol,
                                    brandCol.withValues(alpha: 0.65),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b.$1,
                          style: GoogleFonts.figtree(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: muteCol,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminCategoryDistributionChart extends StatelessWidget {
  const AdminCategoryDistributionChart({
    super.key,
    required this.orders,
  });

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    final categoryTotals = <String, double>{
      'Hot Coffee': 0.0,
      'Iced Coffee': 0.0,
      'Non-Coffee': 0.0,
      'Pastries': 0.0,
      'Merch': 0.0,
    };

    double grandTotal = 0.0;
    for (final order in orders) {
      for (final item in order.items) {
        final cat = item.name.toLowerCase().contains('iced') ||
                item.name.toLowerCase().contains('cold')
            ? 'Iced Coffee'
            : item.name.toLowerCase().contains('matcha') ||
                    item.name.toLowerCase().contains('chocolate') ||
                    item.name.toLowerCase().contains('tea')
                ? 'Non-Coffee'
                : item.name.toLowerCase().contains('croissant') ||
                        item.name.toLowerCase().contains('cookie') ||
                        item.name.toLowerCase().contains('cake')
                    ? 'Pastries'
                    : 'Hot Coffee';

        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + item.total;
        grandTotal += item.total;
      }
    }

    final colors = {
      'Hot Coffee': const Color(0xFF8B5A2B),
      'Iced Coffee': const Color(0xFFD4A373),
      'Non-Coffee': const Color(0xFF4E8752),
      'Pastries': const Color(0xFFE29578),
      'Merch': const Color(0xFF6C757D),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales by Menu Category',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: inkCol,
            ),
          ),
          const SizedBox(height: 14),
          ...categoryTotals.entries.map((entry) {
            final cat = entry.key;
            final amount = entry.value;
            final pct = grandTotal > 0 ? (amount / grandTotal) : 0.0;
            final catCol = colors[cat] ?? Colors.brown;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cat,
                        style: GoogleFonts.figtree(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: inkCol,
                        ),
                      ),
                      Text(
                        '${peso(amount)} (${(pct * 100).toStringAsFixed(0)}%)',
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: catCol,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct > 0 ? pct : 0.02,
                      minHeight: 7,
                      backgroundColor: isDark
                          ? const Color(0xFF332725)
                          : const Color(0xFFEFE8E1),
                      valueColor: AlwaysStoppedAnimation<Color>(catCol),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class AdminOrderStatusDistributionChart extends StatelessWidget {
  const AdminOrderStatusDistributionChart({
    super.key,
    required this.orders,
  });

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;

    final receivedCount = orders.where((o) => o.status == OrderStatus.received).length;
    final preparingCount = orders.where((o) => o.status == OrderStatus.preparing).length;
    final readyCount = orders.where((o) => o.status == OrderStatus.ready).length;
    final completedCount = orders.where((o) => o.status == OrderStatus.completed).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fulfillment Status Distribution',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: inkCol,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusPill('Received', receivedCount, const Color(0xFFD4A373)),
              const SizedBox(width: 8),
              _buildStatusPill('Preparing', preparingCount, const Color(0xFFE29578)),
              const SizedBox(width: 8),
              _buildStatusPill('Ready', readyCount, const Color(0xFF2A9D8F)),
              const SizedBox(width: 8),
              _buildStatusPill('Completed', completedCount, const Color(0xFF457B9D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.figtree(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.figtree(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
