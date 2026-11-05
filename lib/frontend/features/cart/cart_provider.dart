import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:orderacoffee/backend/models/cart_line.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';

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
  CartNotifier() : super(const CartState()) {
    _restoreFromStorage();
  }

  static const String _storageKey = 'coughfee_cart_lines';
  final _uuid = const Uuid();

  Future<void> _restoreFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty && state.lines.isEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final restored = decoded
            .map((e) => CartLine.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (restored.isNotEmpty && mounted && state.lines.isEmpty) {
          state = state.copyWith(lines: restored);
        }
      }
    } catch (_) {
      // Safe no-op in environments where SharedPreferences is not initialized
    }
  }

  Future<void> _persistToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.lines.map((l) => l.toMap()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (_) {}
  }

  // ─── Add ──────────────────────────────────────────────────────────────────

  void addLine(
    MenuItem item,
    CartCustomizations customizations,
    int qty, {
    String note = '',
  }) {
    final cleanNote = note.trim();
    final existingIdx = state.lines.indexWhere(
      (l) =>
          l.itemId == item.id &&
          l.customizations == customizations &&
          l.note == cleanNote,
    );

    if (existingIdx != -1) {
      final existing = state.lines[existingIdx];
      final updatedLines = List<CartLine>.from(state.lines);
      updatedLines[existingIdx] = existing.copyWith(qty: existing.qty + qty);
      state = state.copyWith(lines: updatedLines);
    } else {
      final line = CartLine(
        id: _uuid.v4(),
        itemId: item.id,
        name: item.name,
        basePrice: item.basePrice,
        customizations: customizations,
        qty: qty,
        note: cleanNote,
      );
      state = state.copyWith(lines: [...state.lines, line]);
    }
    unawaited(_persistToStorage());
  }

  // ─── Remove ───────────────────────────────────────────────────────────────

  void removeLine(String lineId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.id != lineId).toList(),
    );
    unawaited(_persistToStorage());
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
    unawaited(_persistToStorage());
  }

  // ─── Update customizations ────────────────────────────────────────────────

  void updateCustomizations(String lineId, CartCustomizations customizations) {
    state = state.copyWith(
      lines: state.lines
          .map((l) =>
              l.id == lineId ? l.copyWith(customizations: customizations) : l)
          .toList(),
    );
    unawaited(_persistToStorage());
  }

  // ─── Update note ──────────────────────────────────────────────────────────

  void updateNote(String lineId, String note) {
    state = state.copyWith(
      lines: state.lines
          .map((l) => l.id == lineId ? l.copyWith(note: note.trim()) : l)
          .toList(),
    );
    unawaited(_persistToStorage());
  }

  // ─── Clear ────────────────────────────────────────────────────────────────

  void clear() {
    state = const CartState();
    unawaited(_persistToStorage());
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
