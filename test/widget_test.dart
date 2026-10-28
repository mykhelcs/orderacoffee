import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/features/auth/login_screen.dart';
import 'package:orderacoffee/widgets/app_logo.dart';
import 'package:orderacoffee/widgets/brand_button.dart';

void main() {
  testWidgets('LoginScreen renders correctly with logo, fields, and login button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppLogo and login screen elements are rendered
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(BrandButton), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
