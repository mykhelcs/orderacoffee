import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/failures.dart';
import '../models/cart_line.dart';
import '../models/menu_item.dart';

class CartRepository {
  CartRepository({this._prefs, Uuid? uuid})
      : _uuid = uuid ?? const Uuid() {
    _initCart();
  }

  static const String _storageKey = 'coughfee_cart_lines';

  SharedPreferences? _prefs;
  final Uuid _uuid;

  final List<CartLine> _lines = [];
  final _cartStreamController = StreamController<List<CartLine>>.broadcast();

  Stream<List<CartLine>> watchCart() => _cartStreamController.stream;

  List<CartLine> get lines => List.unmodifiable(_lines);

  double get totalPrice => _lines.fold(0.0, (sum, line) => sum + line.lineTotal);

  int get itemCount => _lines.fold(0, (sum, line) => sum + line.qty);

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    await _initCart();
  }

  Future<void> _initCart() async {
    if (_prefs == null) return;
    final jsonStr = _prefs!.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        _lines.clear();
        for (final item in decoded) {
          _lines.add(CartLine.fromMap(Map<String, dynamic>.from(item as Map)));
        }
        _notify();
      } catch (_) {
        // Corrupted cache - reset
        _lines.clear();
        await _save();
      }
    }
  }

  Future<void> _save() async {
    if (_prefs != null) {
      final jsonStr = jsonEncode(_lines.map((l) => l.toMap()).toList());
      await _prefs!.setString(_storageKey, jsonStr);
    }
    _notify();
  }

  void _notify() {
    if (!_cartStreamController.isClosed) {
      _cartStreamController.add(List.unmodifiable(_lines));
    }
  }

  /// CT1: Add line to cart
  Future<CartLine> addLine(
    MenuItem item,
    CartCustomizations customizations,
    int qty, {
    String note = '',
  }) async {
    if (qty <= 0) {
      throw const ValidationFailure('Quantity must be greater than zero');
    }

    final line = CartLine(
      id: _uuid.v4(),
      itemId: item.id,
      name: item.name,
      basePrice: item.basePrice,
      customizations: customizations,
      qty: qty,
      note: note,
    );

    _lines.add(line);
    await _save();
    return line;
  }

  /// CT2: Change line quantity (removes line if qty <= 0)
  Future<void> setQty(String lineId, int qty) async {
    final index = _lines.indexWhere((l) => l.id == lineId);
    if (index == -1) {
      throw NotFoundFailure('Cart line not found: $lineId');
    }

    if (qty <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index] = _lines[index].copyWith(qty: qty);
    }
    await _save();
  }

  /// CT3: Edit customizations for an existing line
  Future<void> replaceCustomizations(
    String lineId,
    CartCustomizations newCustomizations,
  ) async {
    final index = _lines.indexWhere((l) => l.id == lineId);
    if (index == -1) {
      throw NotFoundFailure('Cart line not found: $lineId');
    }

    _lines[index] = _lines[index].copyWith(customizations: newCustomizations);
    await _save();
  }

  /// CT4: Update note for a line
  Future<void> setNote(String lineId, String note) async {
    final index = _lines.indexWhere((l) => l.id == lineId);
    if (index == -1) {
      throw NotFoundFailure('Cart line not found: $lineId');
    }

    _lines[index] = _lines[index].copyWith(note: note.trim());
    await _save();
  }

  /// CT5: Remove specific line
  Future<void> removeLine(String lineId) async {
    _lines.removeWhere((l) => l.id == lineId);
    await _save();
  }

  /// CT5: Clear all cart lines
  Future<void> clear() async {
    _lines.clear();
    await _save();
  }

  void dispose() {
    _cartStreamController.close();
  }
}
