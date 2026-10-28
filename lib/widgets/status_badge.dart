import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/order.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
  });

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final text = kOrderLabels[status.name] ?? status.name;

    final isCancelled = status == OrderStatus.cancelled;
    final bg = isCancelled ? AppColors.bad.withValues(alpha: 0.15) : AppColors.crema;
    final fg = isCancelled ? AppColors.bad : const Color(0xFF3A2A00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: GoogleFonts.figtree(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
