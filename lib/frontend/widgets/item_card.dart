import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
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
    final brandCol = isDark ? const Color(0xFFD4A373) : const Color(0xFF3B2314);

    final isAvailable = item.isAvailable;
    final toneColor = _getCategoryTone(item.category);

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lineCol.withValues(alpha: isDark ? 0.6 : 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: isAvailable ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thumbnail (Picture 1 style rounded container)
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: toneColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        ? Image.network(
                            item.imageUrl!,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(brandCol),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: CupIcon(size: 36, color: Color(0xFF5A3825)),
                            ),
                          )
                        : const Center(
                            child: CupIcon(size: 36, color: Color(0xFF5A3825)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  // Name and description (Picture 1 layout)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: GoogleFonts.figtree(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: inkCol,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFavorite) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.favorite_rounded,
                                color: AppColors.bad,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: GoogleFonts.figtree(
                            fontSize: 12.5,
                            color: muteCol,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Sold out',
                            style: GoogleFonts.figtree(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bad,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Price at top-right & Brown '+' button at bottom-right (Picture 1)
                  SizedBox(
                    height: 76,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          peso(item.basePrice),
                          style: GoogleFonts.figtree(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: inkCol,
                          ),
                        ),
                        Material(
                          color: brandCol,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: isAvailable ? onTap : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
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
