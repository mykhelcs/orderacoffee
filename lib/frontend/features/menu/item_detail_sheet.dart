import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/core/utils.dart';
import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/frontend/widgets/cup_icon.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';

class ItemDetailSheet extends ConsumerStatefulWidget {
  const ItemDetailSheet({
    super.key,
    required this.item,
    this.editLine,
  });

  final MenuItem item;
  final CartLine? editLine;

  static Future<void> show(
    BuildContext context,
    MenuItem item, {
    CartLine? editLine,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ItemDetailSheet(
        item: item,
        editLine: editLine,
      ),
    );
  }

  @override
  ConsumerState<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet> {
  late SizeOption _selectedSize;
  late MilkOption _selectedMilk;
  late int _selectedShots;
  late String _selectedSugar;
  late String? _selectedIce;
  late List<AddOnOption> _selectedAddOns;
  late int _qty;
  late TextEditingController _noteController;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    final edit = widget.editLine;

    // Initialize Size
    final defaultSizes = widget.item.options.sizes.isNotEmpty
        ? widget.item.options.sizes
        : const [
            SizeOption(label: 'Small', delta: -15),
            SizeOption(label: 'Medium', delta: 0),
            SizeOption(label: 'Large', delta: 25),
          ];
    _selectedSize = edit?.customizations.size ??
        defaultSizes.firstWhere((s) => s.label == 'Medium',
            orElse: () => defaultSizes.first);

    // Initialize Milk
    final defaultMilks = widget.item.options.milks.isNotEmpty
        ? widget.item.options.milks
        : const [
            MilkOption(label: 'Whole', delta: 0),
            MilkOption(label: 'Oat', delta: 30),
            MilkOption(label: 'Almond', delta: 30),
            MilkOption(label: 'Soy', delta: 20),
          ];
    _selectedMilk = edit?.customizations.milk ??
        defaultMilks.firstWhere(
            (m) => m.label == 'Whole' || m.label == 'Regular',
            orElse: () => defaultMilks.first);

    // Initialize Shots (Picture 2: 1, 2, 3)
    _selectedShots = edit?.customizations.shots ?? 2;

    // Initialize Sugar Level
    final sugarOptions = widget.item.options.sugar.isNotEmpty
        ? widget.item.options.sugar
        : kSugarLevels;
    _selectedSugar = edit?.customizations.sugar ??
        (sugarOptions.contains('100%') ? '100%' : sugarOptions.last);

    // Initialize Ice Level (for Iced Coffee / Cold Drinks)
    if (_isIcedDrink) {
      final iceOptions = widget.item.options.ice.isNotEmpty
          ? widget.item.options.ice
          : kIceLevels;
      _selectedIce = edit?.customizations.ice ??
          (iceOptions.contains('Regular') ? 'Regular' : iceOptions.last);
    } else {
      _selectedIce = edit?.customizations.ice;
    }

    // Initialize AddOns
    _selectedAddOns = List<AddOnOption>.from(edit?.customizations.addOns ?? []);

    _qty = edit?.qty ?? 1;
    _noteController = TextEditingController(text: edit?.note ?? '');

    final initialFavorites =
        ref.read(authProvider).profile?.favorites ?? const <String>[];
    _isFavorite = initialFavorites.contains(widget.item.id);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _isDrink =>
      widget.item.options.sizes.isNotEmpty ||
      widget.item.category.contains('Coffee') ||
      widget.item.category == 'Non-Coffee';

  bool get _isIcedDrink =>
      widget.item.category.toLowerCase().contains('iced') ||
      widget.item.category.toLowerCase().contains('cold') ||
      widget.item.name.toLowerCase().contains('iced') ||
      widget.item.name.toLowerCase().contains('cold');

  double _calculateTotal() {
    if (!_isDrink) {
      return widget.item.basePrice * _qty;
    }
    double unitPrice =
        widget.item.basePrice + _selectedSize.delta + _selectedMilk.delta;
    for (final addOn in _selectedAddOns) {
      unitPrice += addOn.price;
    }
    return unitPrice * _qty;
  }

  Future<void> _handleToggleFavorite() async {
    setState(() => _isFavorite = !_isFavorite);
    await ref.read(authProvider.notifier).toggleFavorite(widget.item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? '${widget.item.name} added to Favorites'
                : '${widget.item.name} removed from Favorites',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _saveOrAddToCart() {
    final cust = CartCustomizations(
      size: _isDrink ? _selectedSize : null,
      milk: _isDrink ? _selectedMilk : null,
      shots: _isDrink ? _selectedShots : null,
      sugar: _isDrink ? _selectedSugar : null,
      ice: (_isDrink && _isIcedDrink) ? _selectedIce : null,
      addOns: _isDrink ? _selectedAddOns : const [],
    );

    final cartNotifier = ref.read(cartProvider.notifier);
    final cleanNote = _noteController.text.trim();

    if (widget.editLine != null) {
      cartNotifier.updateCustomizations(widget.editLine!.id, cust);
      cartNotifier.updateQty(widget.editLine!.id, _qty);
      cartNotifier.updateNote(widget.editLine!.id, cleanNote);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart updated')),
      );
    } else {
      cartNotifier.addLine(
        widget.item,
        cust,
        _qty,
        note: cleanNote,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.item.name} added to cart')),
      );
    }
  }

  Widget _buildSectionTitle(String title, Color inkCol) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.figtree(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: inkCol,
        ),
      ),
    );
  }

  Widget _buildPillOption({
    required Widget child,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeBg,
    required Color inactiveBg,
    required Color activeText,
    required Color inactiveText,
  }) {
    return Material(
      color: isSelected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
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
    final activePillBg =
        isDark ? const Color(0xFFD4A373) : const Color(0xFF3B2314);
    final activePillText = isDark ? const Color(0xFF1B120C) : Colors.white;
    final inactivePillBg =
        isDark ? const Color(0xFF2C2425) : const Color(0xFFF5F1EB);
    final inactivePillText =
        isDark ? AppColors.inkDark : const Color(0xFF3B2314);

    final availableSizes = widget.item.options.sizes.isNotEmpty
        ? widget.item.options.sizes
        : const [
            SizeOption(label: 'Small', delta: -15),
            SizeOption(label: 'Medium', delta: 0),
            SizeOption(label: 'Large', delta: 25),
          ];

    final availableMilks = widget.item.options.milks.isNotEmpty
        ? widget.item.options.milks
        : const [
            MilkOption(label: 'Whole', delta: 0),
            MilkOption(label: 'Oat', delta: 30),
            MilkOption(label: 'Almond', delta: 30),
            MilkOption(label: 'Soy', delta: 20),
          ];

    final availableSugar = widget.item.options.sugar.isNotEmpty
        ? widget.item.options.sugar
        : kSugarLevels;

    final availableIce = widget.item.options.ice.isNotEmpty
        ? widget.item.options.ice
        : kIceLevels;

    final availableAddOns = widget.item.options.addOns.isNotEmpty
        ? widget.item.options.addOns
        : const [
            AddOnOption(label: 'Extra Shot', price: 40),
            AddOnOption(label: 'Vanilla Syrup', price: 25),
          ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: BoxDecoration(
        color: bgCanvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Header Bar (Picture 2: Back arrow, "Customize" title, Heart icon)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon:
                      Icon(Icons.arrow_back_rounded, color: inkCol, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'Customize',
                  style: GoogleFonts.figtree(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: inkCol,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? AppColors.bad : inkCol,
                    size: 24,
                  ),
                  onPressed: _handleToggleFavorite,
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Top Hero Coffee Visual (Picture 2)
                Container(
                  height: 180,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: (widget.item.imageUrl != null &&
                          widget.item.imageUrl!.isNotEmpty)
                      ? Image.network(
                          widget.item.imageUrl!,
                          height: 170,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    activePillBg),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Center(
                            child: CupIcon(size: 80, color: activePillBg),
                          ),
                        )
                      : Center(
                          child: CupIcon(size: 80, color: activePillBg),
                        ),
                ),

                // Overlapping Rounded Card (Picture 2)
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drink Name & Price Row (Picture 2)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: GoogleFonts.figtree(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: inkCol,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            peso(widget.item.basePrice),
                            style: GoogleFonts.figtree(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: inkCol,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Description
                      Text(
                        widget.item.description,
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          color: muteCol,
                          height: 1.35,
                        ),
                      ),

                      if (_isDrink) ...[
                        // ── SIZE SECTION (Picture 2) ────────────────────────
                        _buildSectionTitle('Size', inkCol),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: availableSizes.map((s) {
                              final isSelected =
                                  _selectedSize.label == s.label;
                              String displayLabel = s.label;
                              if (s.label == 'Small') displayLabel = 'S';
                              if (s.label == 'Medium') displayLabel = 'M';
                              if (s.label == 'Large') displayLabel = 'L';

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildPillOption(
                                  child: Text(
                                    displayLabel,
                                    style: GoogleFonts.figtree(
                                      fontSize: 14.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? activePillText
                                          : inactivePillText,
                                    ),
                                  ),
                                  isSelected: isSelected,
                                  activeBg: activePillBg,
                                  inactiveBg: inactivePillBg,
                                  activeText: activePillText,
                                  inactiveText: inactivePillText,
                                  onTap: () =>
                                      setState(() => _selectedSize = s),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── MILK SECTION (Picture 2) ────────────────────────
                        _buildSectionTitle('Milk', inkCol),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: availableMilks.map((m) {
                              final isSelected =
                                  _selectedMilk.label == m.label;
                              final displayLabel =
                                  m.label == 'Whole' ? 'Regular' : m.label;

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildPillOption(
                                  child: Text(
                                    displayLabel,
                                    style: GoogleFonts.figtree(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? activePillText
                                          : inactivePillText,
                                    ),
                                  ),
                                  isSelected: isSelected,
                                  activeBg: activePillBg,
                                  inactiveBg: inactivePillBg,
                                  activeText: activePillText,
                                  inactiveText: inactivePillText,
                                  onTap: () =>
                                      setState(() => _selectedMilk = m),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── SHOTS SECTION (Picture 2) ───────────────────────
                        _buildSectionTitle('Shots', inkCol),
                        Row(
                          children: [1, 2, 3].map((shotCount) {
                            final isSelected = _selectedShots == shotCount;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _buildPillOption(
                                child: Text(
                                  '$shotCount',
                                  style: GoogleFonts.figtree(
                                    fontSize: 14.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? activePillText
                                        : inactivePillText,
                                  ),
                                ),
                                isSelected: isSelected,
                                activeBg: activePillBg,
                                inactiveBg: inactivePillBg,
                                activeText: activePillText,
                                inactiveText: inactivePillText,
                                onTap: () =>
                                    setState(() => _selectedShots = shotCount),
                              ),
                            );
                          }).toList(),
                        ),

                        // ── SUGAR LEVEL SECTION ─────────────────────────────
                        _buildSectionTitle('Sweetness', inkCol),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: availableSugar.map((sugarLevel) {
                              final isSelected = _selectedSugar == sugarLevel;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _buildPillOption(
                                  child: Text(
                                    sugarLevel,
                                    style: GoogleFonts.figtree(
                                      fontSize: 13.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? activePillText
                                          : inactivePillText,
                                    ),
                                  ),
                                  isSelected: isSelected,
                                  activeBg: activePillBg,
                                  inactiveBg: inactivePillBg,
                                  activeText: activePillText,
                                  inactiveText: inactivePillText,
                                  onTap: () => setState(
                                      () => _selectedSugar = sugarLevel),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── ICE LEVEL SECTION (Iced Drinks) ─────────────────
                        if (_isIcedDrink) ...[
                          _buildSectionTitle('Ice Level', inkCol),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: availableIce.map((iceLevel) {
                                final isSelected = _selectedIce == iceLevel;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _buildPillOption(
                                    child: Text(
                                      iceLevel,
                                      style: GoogleFonts.figtree(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? activePillText
                                            : inactivePillText,
                                      ),
                                    ),
                                    isSelected: isSelected,
                                    activeBg: activePillBg,
                                    inactiveBg: inactivePillBg,
                                    activeText: activePillText,
                                    inactiveText: inactivePillText,
                                    onTap: () =>
                                        setState(() => _selectedIce = iceLevel),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],

                        // ── EXTRA SECTION (Picture 2 Checkboxes) ─────────────
                        _buildSectionTitle('Extra', inkCol),
                        ...availableAddOns.map((addon) {
                          final isChecked = _selectedAddOns.any((a) =>
                              a.label.toLowerCase() ==
                              addon.label.toLowerCase());

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedAddOns.removeWhere((a) =>
                                        a.label.toLowerCase() ==
                                        addon.label.toLowerCase());
                                  } else {
                                    _selectedAddOns.add(addon);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    // Custom rounded checkbox (Picture 2)
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isChecked
                                            ? activePillBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color:
                                              isChecked ? activePillBg : lineCol,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isChecked
                                          ? Icon(Icons.check,
                                              size: 16, color: activePillText)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        addon.label,
                                        style: GoogleFonts.figtree(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          color: inkCol,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      peso(addon.price),
                                      style: GoogleFonts.figtree(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: muteCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],

                      // ── SPECIAL INSTRUCTIONS / NOTE ───────────────────────
                      _buildSectionTitle('Special Instructions', inkCol),
                      Container(
                        decoration: BoxDecoration(
                          color: inactivePillBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: lineCol),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        child: TextField(
                          controller: _noteController,
                          maxLines: 2,
                          style: GoogleFonts.figtree(
                            fontSize: 13.5,
                            color: inkCol,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'E.g. Extra hot, less foam, oat milk on the side...',
                            hintStyle: GoogleFonts.figtree(
                              fontSize: 13,
                              color: muteCol,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── DOCKED BOTTOM BAR (Picture 2) ───────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                  top: BorderSide(color: lineCol.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                // Quantity Stepper pill [- 1 +]
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: inactivePillBg,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        color: inkCol,
                        onPressed: () {
                          if (_qty > 1) {
                            setState(() => _qty--);
                          }
                        },
                      ),
                      Text(
                        '$_qty',
                        style: GoogleFonts.figtree(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: inkCol,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        color: inkCol,
                        onPressed: () => setState(() => _qty++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Add to Cart / Save changes dark brown pill button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveOrAddToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activePillBg,
                        foregroundColor: activePillText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.editLine != null
                                ? 'Save Changes'
                                : 'Add to Cart',
                            style: GoogleFonts.figtree(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: activePillText,
                            ),
                          ),
                          Text(
                            peso(_calculateTotal()),
                            style: GoogleFonts.figtree(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: activePillText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
