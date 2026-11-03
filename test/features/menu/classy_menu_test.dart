import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/backend/models/menu_item.dart';
import 'package:orderacoffee/backend/seed/seed_menu_data.dart';
import 'package:orderacoffee/core/constants.dart';
import 'package:orderacoffee/frontend/features/menu/menu_screen.dart';
import 'package:orderacoffee/frontend/features/profile/profile_screen.dart';
import 'package:orderacoffee/frontend/widgets/app_logo.dart';
import 'package:orderacoffee/frontend/widgets/item_card.dart';

void main() {
  group('Classy Products & UI Refinements Tests', () {
    test('Default menu catalog contains items for all 5 required categories', () {
      final categories = kDefaultMenuItems.map((e) => e.category).toSet();
      expect(categories, containsAll([
        'Hot Coffee',
        'Iced Coffee',
        'Non-Coffee',
        'Pastries',
        'Merch',
      ]));

      // Verify each category has multiple classy items
      expect(kDefaultMenuItems.where((e) => e.category == 'Hot Coffee').length, greaterThanOrEqualTo(5));
      expect(kDefaultMenuItems.where((e) => e.category == 'Iced Coffee').length, greaterThanOrEqualTo(5));
      expect(kDefaultMenuItems.where((e) => e.category == 'Non-Coffee').length, greaterThanOrEqualTo(5));
      expect(kDefaultMenuItems.where((e) => e.category == 'Pastries').length, greaterThanOrEqualTo(5));
      expect(kDefaultMenuItems.where((e) => e.category == 'Merch').length, greaterThanOrEqualTo(5));
    });

    test('All 37 menu products have real photography imageUrl assigned', () {
      expect(kDefaultMenuItems.length, 37);
      for (final item in kDefaultMenuItems) {
        expect(item.imageUrl, isNotNull, reason: '${item.name} should have an imageUrl');
        expect(item.imageUrl, isNotEmpty, reason: '${item.name} imageUrl should not be empty');
        expect(item.imageUrl!.startsWith('http'), isTrue, reason: '${item.name} imageUrl should be a valid URL');
      }
    });

    test('defaultDrinkOptions includes all required customization options and add-ons', () {
      expect(defaultDrinkOptions.sizes.map((s) => s.label), containsAll(['Small', 'Medium', 'Large']));
      expect(defaultDrinkOptions.milks.map((m) => m.label), containsAll(['Whole', 'Oat', 'Almond', 'Soy']));
      expect(defaultDrinkOptions.sugar, containsAll(['0%', '25%', '50%', '75%', '100%']));
      expect(defaultDrinkOptions.ice, containsAll(['No ice', 'Less', 'Regular']));

      final addOnLabels = defaultDrinkOptions.addOns.map((a) => a.label).toList();
      expect(addOnLabels, containsAll([
        'Extra shot',
        'Vanilla syrup',
        'Caramel drizzle',
        'Whipped cream',
        'Sea salt cold foam',
      ]));
    });

    test('kAddons constant matches drink add-on qualifications', () {
      final addonLabels = kAddons.map((a) => a.$1).toList();
      expect(addonLabels, containsAll([
        'Extra shot',
        'Vanilla syrup',
        'Whipped cream',
      ]));
    });

    testWidgets('AppLogo with showSubtitle: false omits the comfort brew tagline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(showSubtitle: false),
          ),
        ),
      );

      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('CafeGO'),
      );
      expect(richTextFinder, findsOneWidget);
      expect(find.text('Your daily comfort brew'), findsNothing);
    });

    testWidgets('ItemCard renders Image.network when item has imageUrl', (tester) async {
      const itemWithImage = MenuItem(
        id: 'test-item',
        name: 'Test Latte',
        category: 'Hot Coffee',
        description: 'Test description',
        basePrice: 150,
        imageUrl: 'https://images.unsplash.com/photo-1541167760496-1628856ab772',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemCard(item: itemWithImage),
          ),
        ),
      );

      final networkImageFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == itemWithImage.imageUrl,
      );
      expect(networkImageFinder, findsOneWidget);
    });

    testWidgets('MenuScreen renders cropped splash image and search bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MenuScreen(),
            ),
          ),
        ),
      );

      // Verify cropped splash image in hero banner
      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/coffee_splash.jpg',
      );
      expect(imageFinder, findsOneWidget);

      // Verify readable search field
      final searchFieldFinder = find.byType(TextField);
      expect(searchFieldFinder, findsOneWidget);
      expect(find.text('Search handcrafted coffee & fresh bakery...'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders without ListTile invisible ink splash exceptions', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify profile tiles are displayed
      expect(find.text('Order History'), findsOneWidget);
      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('Delivery Addresses'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Help & FAQ'), findsOneWidget);
      expect(find.text('CafeGO Store Locator'), findsOneWidget);

      // Verify that no Flutter exceptions were thrown
      expect(tester.takeException(), isNull);
    });
  });
}
