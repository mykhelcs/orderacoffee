import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/cart_line.dart';
import '../../data/models/menu_item.dart';
import '../../widgets/brand_button.dart';
import '../../widgets/ghost_button.dart';
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
  late String _selectedSugar;
  late String _selectedIce;
  late List<AddOnOption> _selectedAddOns;
  late int _qty;
  late TextEditingController _noteController;

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
        defaultSizes.firstWhere((s) => s.label == 'Medium', orElse: () => defaultSizes.first);

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
        defaultMilks.firstWhere((m) => m.label == 'Whole', orElse: () => defaultMilks.first);

    // Initialize Sugar & Ice
    _selectedSugar = edit?.customizations.sugar ?? '50%';
    _selectedIce = edit?.customizations.ice ?? 'Regular';

    // Initialize AddOns
    _selectedAddOns = List<AddOnOption>.from(edit?.customizations.addOns ?? []);

    _qty = edit?.qty ?? 1;
    _noteController = TextEditingController(text: edit?.note ?? '');
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

  double _calculateTotal() {
    if (!_isDrink) {
      return widget.item.basePrice * _qty;
    }
    double unitPrice = widget.item.basePrice + _selectedSize.delta + _selectedMilk.delta;
    for (final addOn in _selectedAddOns) {
      unitPrice += addOn.price;
    }
    return unitPrice * _qty;
  }

  void _saveOrAddToCart() {
    final cust = CartCustomizations(
      size: _isDrink ? _selectedSize : null,
      milk: _isDrink ? _selectedMilk : null,
      sugar: _isDrink ? _selectedSugar : null,
      ice: _isDrink ? _selectedIce : null,
      addOns: _isDrink ? _selectedAddOns : const [],
    );

    final cartNotifier = ref.read(cartProvider.notifier);

    if (widget.editLine != null) {
      cartNotifier.updateCustomizations(widget.editLine!.id, cust);
      cartNotifier.updateQty(widget.editLine!.id, _qty);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart updated')),
      );
    } else {
      cartNotifier.addLine(
        widget.item,
        cust,
        _qty,
        note: _noteController.text.trim(),
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.item.name} added to cart')),
      );
    }
  }

  Widget _buildGroupTitle(String title, Color inkCol) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.figtree(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: inkCol,
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color cardBg,
    required Color lineCol,
    required Color brandCol,
    required Color inkCol,
  }) {
    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? brandCol : lineCol,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.figtree(
              color: isSelected ? brandCol : inkCol,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

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
            AddOnOption(label: 'Extra shot', price: 40),
            AddOnOption(label: 'Vanilla syrup', price: 25),
            AddOnOption(label: 'Caramel syrup', price: 25),
            AddOnOption(label: 'Whipped cream', price: 20),
          ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: inkCol,
                    ),
                  ),
                ),
                GhostButton(
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Scrollable Options
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Text(
                  widget.item.description,
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    color: muteCol,
                  ),
                ),
                if (_isDrink) ...[
                  // Size
                  _buildGroupTitle('Size', inkCol),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSizes.map((s) {
                      final deltaStr = s.delta == 0
                          ? ''
                          : s.delta > 0
                              ? ' (+${peso(s.delta)})'
                              : ' (-${peso(s.delta.abs())})';
                      return _buildOptionButton(
                        label: '${s.label}$deltaStr',
                        isSelected: _selectedSize.label == s.label,
                        cardBg: cardBg,
                        lineCol: lineCol,
                        brandCol: brandCol,
                        inkCol: inkCol,
                        onTap: () => setState(() => _selectedSize = s),
                      );
                    }).toList(),
                  ),
                  // Milk
                  _buildGroupTitle('Milk', inkCol),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableMilks.map((m) {
                      final deltaStr = m.delta == 0 ? '' : ' (+${peso(m.delta)})';
                      return _buildOptionButton(
                        label: '${m.label}$deltaStr',
                        isSelected: _selectedMilk.label == m.label,
                        cardBg: cardBg,
                        lineCol: lineCol,
                        brandCol: brandCol,
                        inkCol: inkCol,
                        onTap: () => setState(() => _selectedMilk = m),
                      );
                    }).toList(),
                  ),
                  // Sugar Level
                  _buildGroupTitle('Sugar level', inkCol),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSugar.map((s) {
                      return _buildOptionButton(
                        label: s,
                        isSelected: _selectedSugar == s,
                        cardBg: cardBg,
                        lineCol: lineCol,
                        brandCol: brandCol,
                        inkCol: inkCol,
                        onTap: () => setState(() => _selectedSugar = s),
                      );
                    }).toList(),
                  ),
                  // Ice
                  _buildGroupTitle('Ice', inkCol),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableIce.map((i) {
                      return _buildOptionButton(
                        label: i,
                        isSelected: _selectedIce == i,
                        cardBg: cardBg,
                        lineCol: lineCol,
                        brandCol: brandCol,
                        inkCol: inkCol,
                        onTap: () => setState(() => _selectedIce = i),
                      );
                    }).toList(),
                  ),
                  // Add-ons
                  _buildGroupTitle('Add-ons', inkCol),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableAddOns.map((a) {
                      final isSelected =
                          _selectedAddOns.any((x) => x.label == a.label);
                      return _buildOptionButton(
                        label: '${a.label} (+${peso(a.price)})',
                        isSelected: isSelected,
                        cardBg: cardBg,
                        lineCol: lineCol,
                        brandCol: brandCol,
                        inkCol: inkCol,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAddOns
                                  .removeWhere((x) => x.label == a.label);
                            } else {
                              _selectedAddOns.add(a);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                // Special note
                _buildGroupTitle('Special note', inkCol),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Anything we should know?',
                  ),
                ),
                // Quantity Row
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity',
                        style: GoogleFonts.figtree(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: inkCol,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: lineCol),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () {
                                if (_qty > 1) {
                                  setState(() => _qty--);
                                }
                              },
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 28),
                              alignment: Alignment.center,
                              child: Text(
                                '$_qty',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: inkCol,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _qty++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          // Action button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: BrandButton(
              label: widget.editLine != null ? 'Save changes' : 'Add to cart',
              trailing: peso(_calculateTotal()),
              onPressed: _saveOrAddToCart,
            ),
          ),
        ],
      ),
    );
  }
}
