import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/cart_line.dart';
import '../../data/models/menu_item.dart';

// ─── CartState ────────────────────────────────────────────────────────────────

class CartState {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  double get total => lines.fold(0.0, (sum, l) => sum + l.lineTotal);
  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  CartState copyWith({List<CartLine>? lines}) {
    return CartState(lines: lines ?? this.lines);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartState &&
          runtimeType == other.runtimeType &&
          lines == other.lines;

  @override
  int get hashCode => lines.hashCode;
}

// ─── CartNotifier ─────────────────────────────────────────────────────────────

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  final _uuid = const Uuid();

  // ─── Add ──────────────────────────────────────────────────────────────────

  void addLine(
    MenuItem item,
    CartCustomizations customizations,
    int qty, {
    String note = '',
  }) {
    final line = CartLine(
      id: _uuid.v4(),
      itemId: item.id,
      name: item.name,
      basePrice: item.basePrice,
      customizations: customizations,
      qty: qty,
      note: note,
    );
    state = state.copyWith(lines: [...state.lines, line]);
  }

  // ─── Remove ───────────────────────────────────────────────────────────────

  void removeLine(String lineId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.id != lineId).toList(),
    );
  }

  // ─── Update qty ───────────────────────────────────────────────────────────

  void updateQty(String lineId, int qty) {
    if (qty <= 0) {
      removeLine(lineId);
      return;
    }
    state = state.copyWith(
      lines: state.lines
          .map((l) => l.id == lineId ? l.copyWith(qty: qty) : l)
          .toList(),
    );
  }

  // ─── Update customizations ────────────────────────────────────────────────

  void updateCustomizations(String lineId, CartCustomizations customizations) {
    state = state.copyWith(
      lines: state.lines
          .map((l) =>
              l.id == lineId ? l.copyWith(customizations: customizations) : l)
          .toList(),
    );
  }

  // ─── Clear ────────────────────────────────────────────────────────────────

  void clear() => state = const CartState();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
