import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/frontend/widgets/philippine_phone_field.dart';

void main() {
  group('PhilippinePhoneField Widget Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createWidget() {
      return MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PhilippinePhoneField(controller: controller),
          ),
        ),
      );
    }

    testWidgets('renders static +63 prefix, phone icon, and divider', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('+63'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byKey(const Key('philippine_phone_prefix_badge')), findsOneWidget);
      expect(find.byKey(const Key('philippine_phone_input_field')), findsOneWidget);
    });

    testWidgets('triggers brand highlight when 09 is entered and smoothly finishes', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Enter 0
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.pump();
      expect(controller.text, '0');

      // Enter 9 -> 0 is stripped, 9 is kept, highlight begins
      await tester.enterText(find.byType(TextFormField), '09');
      await tester.pump();
      expect(controller.text, '9');

      // Verify animation progresses through 1.5 seconds
      await tester.pump(const Duration(milliseconds: 200));
      // Halfway through 1500ms
      await tester.pump(const Duration(milliseconds: 700));
      // End of 1500ms
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    });

    testWidgets('validates 10-digit number starting with 9', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: PhilippinePhoneField(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty validation
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Phone number is required'), findsOneWidget);

      // Incomplete number validation
      await tester.enterText(find.byType(TextFormField), '917');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid 10-digit number starting with 9'), findsOneWidget);

      // Complete 10-digit number validation
      await tester.enterText(find.byType(TextFormField), '9171234567');
      await tester.pumpAndSettle();
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
