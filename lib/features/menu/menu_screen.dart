import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/cup_icon.dart';
import '../../widgets/item_card.dart';
import '../auth/auth_provider.dart';
import 'item_detail_sheet.dart';
import 'menu_provider.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    final filter = ref.watch(menuFilterProvider);
    final items = ref.watch(filteredMenuProvider);
    final favorites = ref.watch(userFavoritesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Hero Banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: brandCol,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -15,
                child: Opacity(
                  opacity: 0.9,
                  child: CupIcon(
                    size: 130,
                    color: isDark ? AppColors.onBrandDark : AppColors.onBrandLight,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      'Order ahead.\nSkip the line.',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: isDark ? AppColors.onBrandDark : AppColors.onBrandLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your usual, ready when you walk in.',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: (isDark ? AppColors.onBrandDark : AppColors.onBrandLight)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (q) => ref.read(menuFilterProvider.notifier).setQuery(q),
          decoration: InputDecoration(
            hintText: 'Search drinks and pastries',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(menuFilterProvider.notifier).setQuery('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kCategories.map((cat) {
              final isSelected = filter.category == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected ? inkCol : cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(
                      color: isSelected ? inkCol : lineCol,
                    ),
                  ),
                  child: InkWell(
                    onTap: () =>
                        ref.read(menuFilterProvider.notifier).setCategory(cat),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? cardBg : inkCol,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Item list or Empty
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Text(
                  'No matches',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: inkCol,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try another name or pick a different category.',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    color: muteCol,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...items.map(
            (item) => ItemCard(
              item: item,
              isFavorite: favorites.contains(item.id),
              onTap: () => ItemDetailSheet.show(context, item),
            ),
          ),
      ],
    );
  }
}
