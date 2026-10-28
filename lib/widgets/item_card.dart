import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/models/menu_item.dart';
import 'cup_icon.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    this.isFavorite = false,
    this.onTap,
  });

  final MenuItem item;
  final bool isFavorite;
  final VoidCallback? onTap;

  Color _getCategoryTone(String category) {
    switch (category) {
      case 'Hot Coffee':
        return AppColors.toneHotCoffee;
      case 'Iced Coffee':
        return AppColors.toneIcedCoffee;
      case 'Non-Coffee':
        return AppColors.toneNonCoffee;
      case 'Pastry':
      case 'Pastries':
        return AppColors.tonePastries;
      case 'Merch':
        return AppColors.toneMerch;
      default:
        return AppColors.toneHotCoffee;
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

    final isAvailable = item.isAvailable;
    final toneColor = _getCategoryTone(item.category);

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lineCol),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: isAvailable ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: toneColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const CupIcon(size: 34, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: inkCol,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFavorite) ...[
                              const SizedBox(width: 4),
                              const Text('♥', style: TextStyle(color: AppColors.bad, fontSize: 13)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description,
                          style: GoogleFonts.figtree(
                            fontSize: 13,
                            color: muteCol,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Sold out',
                            style: GoogleFonts.figtree(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bad,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Price
                  Text(
                    peso(item.basePrice),
                    style: GoogleFonts.figtree(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: inkCol,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
