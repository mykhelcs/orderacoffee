import 'package:flutter/material.dart' hide StepState;
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/data/models/order.dart';
import 'package:orderacoffee/widgets/step_tracker.dart';

void main() {
  group('StepTracker Widget Tests', () {
    Widget buildTracker(OrderStatus status) {
      return MaterialApp(
        home: Scaffold(
          body: StepTracker(status: status),
        ),
      );
    }

    testWidgets('renders all 4 status labels', (tester) async {
      await tester.pumpWidget(buildTracker(OrderStatus.received));

      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.text('Ready for pickup'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('highlights current step for received', (tester) async {
      await tester.pumpWidget(buildTracker(OrderStatus.received));

      final stepFinder = find.byType(StepItemWidget);
      expect(stepFinder, findsNWidgets(4));

      final firstStep = tester.widget<StepItemWidget>(stepFinder.at(0));
      expect(firstStep.state, StepState.current);

      final secondStep = tester.widget<StepItemWidget>(stepFinder.at(1));
      expect(secondStep.state, StepState.future);
    });

    testWidgets('marks past steps as done when preparing', (tester) async {
      await tester.pumpWidget(buildTracker(OrderStatus.preparing));

      final stepFinder = find.byType(StepItemWidget);
      final firstStep = tester.widget<StepItemWidget>(stepFinder.at(0));
      expect(firstStep.state, StepState.done);

      final secondStep = tester.widget<StepItemWidget>(stepFinder.at(1));
      expect(secondStep.state, StepState.current);

      final thirdStep = tester.widget<StepItemWidget>(stepFinder.at(2));
      expect(thirdStep.state, StepState.future);
    });

    testWidgets('marks all steps done when completed', (tester) async {
      await tester.pumpWidget(buildTracker(OrderStatus.completed));

      final stepFinder = find.byType(StepItemWidget);
      for (int i = 0; i < 4; i++) {
        final step = tester.widget<StepItemWidget>(stepFinder.at(i));
        expect(step.state, StepState.done);
      }
    });
  });
}
