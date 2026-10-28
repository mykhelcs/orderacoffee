import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/core/errors/failures.dart';
import 'package:orderacoffee/data/models/cart_line.dart';
import 'package:orderacoffee/data/models/menu_item.dart';
import 'package:orderacoffee/data/repositories/cart_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CartRepository (CT1 - CT5)', () {
    late CartRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = CartRepository(prefs: prefs);
    });

    tearDown(() {
      repository.dispose();
    });

    const sampleItem = MenuItem(
      id: 'item_spanish_latte',
      name: 'Spanish Latte',
      category: 'Hot Coffee',
      description: 'Sweet and creamy espresso',
      basePrice: 120.0,
    );

    test('CT1: addLine calculates line price correctly and updates totals', () async {
      const customizations = CartCustomizations(
        size: SizeOption(label: 'Large', delta: 20.0),
        milk: MilkOption(label: 'Oat', delta: 30.0),
        sugar: '50%',
        ice: 'Regular',
        addOns: [AddOnOption(label: 'Extra Shot', price: 25.0)],
      );

      final line = await repository.addLine(
        sampleItem,
        customizations,
        2,
        note: 'Less sweet',
      );

      expect(line.unitPrice, 120.0 + 20.0 + 30.0 + 25.0); // 195.0
      expect(line.lineTotal, 195.0 * 2); // 390.0
      expect(repository.lines.length, 1);
      expect(repository.totalPrice, 390.0);
      expect(repository.itemCount, 2);
    });

    test('CT1: addLine rejects quantity <= 0', () async {
      expect(
        () => repository.addLine(sampleItem, const CartCustomizations(), 0),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('CT2: setQty changes quantity and removes line when qty is 0', () async {
      final line = await repository.addLine(
        sampleItem,
        const CartCustomizations(),
        1,
      );

      await repository.setQty(line.id, 3);
      expect(repository.lines.first.qty, 3);
      expect(repository.itemCount, 3);

      await repository.setQty(line.id, 0);
      expect(repository.lines, isEmpty);
      expect(repository.itemCount, 0);
    });

    test('CT2: setQty throws NotFoundFailure for non-existent lineId', () async {
      expect(
        () => repository.setQty('invalid_line_id', 2),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('CT3: replaceCustomizations updates options and recalculates total', () async {
      final line = await repository.addLine(
        sampleItem,
        const CartCustomizations(size: SizeOption(label: 'Regular', delta: 0.0)),
        1,
      );
      expect(repository.totalPrice, 120.0);

      await repository.replaceCustomizations(
        line.id,
        const CartCustomizations(
          size: SizeOption(label: 'Large', delta: 20.0),
          milk: MilkOption(label: 'Almond', delta: 25.0),
        ),
      );

      expect(repository.lines.first.unitPrice, 120.0 + 20.0 + 25.0); // 165.0
      expect(repository.totalPrice, 165.0);
    });

    test('CT4: setNote updates line note', () async {
      final line = await repository.addLine(
        sampleItem,
        const CartCustomizations(),
        1,
      );

      await repository.setNote(line.id, 'Extra hot please');
      expect(repository.lines.first.note, 'Extra hot please');
    });

    test('CT5: removeLine and clear', () async {
      final line1 = await repository.addLine(sampleItem, const CartCustomizations(), 1);
      final line2 = await repository.addLine(sampleItem, const CartCustomizations(), 1);
      expect(repository.lines.length, 2);

      await repository.removeLine(line1.id);
      expect(repository.lines.length, 1);
      expect(repository.lines.first.id, line2.id);

      await repository.clear();
      expect(repository.lines, isEmpty);
      expect(repository.totalPrice, 0.0);
    });

    test('Persistence: loads saved cart lines from SharedPreferences on init', () async {
      await repository.addLine(sampleItem, const CartCustomizations(), 2);
      expect(repository.lines.length, 1);

      // Create a second repository instance with same SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final restoredRepo = CartRepository(prefs: prefs);

      expect(restoredRepo.lines.length, 1);
      expect(restoredRepo.lines.first.name, 'Spanish Latte');
      expect(restoredRepo.lines.first.qty, 2);
      restoredRepo.dispose();
    });
  });
}
