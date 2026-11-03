import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/item_card.dart';
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
    final favorites = ref.watch(authProvider).profile?.favorites ?? const <String>[];

    // Featured picks for the top spotlight carousel
    final featuredItems = items.take(4).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Luxury CafeGO Hero Banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF382319), Color(0xFF1E1410)]
                  : const [Color(0xFF5A3825), Color(0xFF382014)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1410).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD49755),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'DAILY SPECIAL',
                            style: GoogleFonts.figtree(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: const Color(0xFF1B110B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'CafeGO Comfort Club',
                            style: GoogleFonts.figtree(
                              fontSize: 11,
                              color: const Color(0xFFD4C8C2),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your daily comfort brew.',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: const Color(0xFFF7F1EB),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order ahead. Freshly handcrafted when you arrive.',
                      style: GoogleFonts.figtree(
                        fontSize: 12.5,
                        color: const Color(0xFFE2D6CF).withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Cropped splashscreen coffee visual
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFD49755).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.5),
                  child: Image.asset(
                    'assets/images/coffee_splash.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search bar in matching latte pill style
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2425) : const Color(0xFFEDE4DC),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? const Color(0xFF3F3536) : const Color(0xFFDDD2C7),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (q) => ref.read(menuFilterProvider.notifier).setQuery(q),
            style: GoogleFonts.figtree(
              color: inkCol,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search handcrafted coffee & fresh bakery...',
              hintStyle: GoogleFonts.figtree(
                color: muteCol.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: brandCol,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18, color: muteCol),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(menuFilterProvider.notifier).setQuery('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Category pills selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kCategories.map((cat) {
              final isSelected = filter.category == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected ? brandCol : cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                    side: BorderSide(
                      color: isSelected ? brandCol : lineCol,
                    ),
                  ),
                  child: InkWell(
                    onTap: () =>
                        ref.read(menuFilterProvider.notifier).setCategory(cat),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      constraints: const BoxConstraints(minHeight: 38),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? AppColors.onBrandDark : AppColors.onBrandLight)
                              : inkCol,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Spotlight Featured Section when on "All" category and no search
        if (filter.category == 'All' && filter.query.isEmpty && featuredItems.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Barista Picks',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: inkCol,
                ),
              ),
              Text(
                'Handcrafted Favorites',
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  color: muteCol,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 145,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featuredItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final item = featuredItems[idx];
                return GestureDetector(
                  onTap: () => ItemDetailSheet.show(context, item),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: lineCol),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD49755).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category,
                                style: GoogleFonts.figtree(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD49755),
                                ),
                              ),
                            ),
                            Icon(
                              favorites.contains(item.id)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: favorites.contains(item.id)
                                  ? AppColors.bad
                                  : muteCol,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          item.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: inkCol,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          peso(item.basePrice),
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: brandCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
        ],

        // Menu items section title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              filter.category == 'All' ? 'Full Menu' : filter.category,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: inkCol,
              ),
            ),
            Text(
              '${items.length} items',
              style: GoogleFonts.figtree(
                fontSize: 12,
                color: muteCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Item list or Empty state
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(
                  Icons.coffee_outlined,
                  size: 48,
                  color: muteCol.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No brews found',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: inkCol,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try searching for another drink or pick a different category.',
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
        const SizedBox(height: 24),
      ],
    );
  }
}
