import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderacoffee/frontend/features/auth/login_screen.dart';
import 'package:orderacoffee/frontend/widgets/app_logo.dart';

void main() {
  testWidgets('LoginScreen renders correctly with tabs, fields, and login button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify CafeGO Sign In screen elements match reference
    expect(find.text('CafeGO'), findsOneWidget);
    expect(find.text('Your daily comfort brew'), findsOneWidget);
    expect(find.byType(AppLogo), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text("Don't have an account yet?"), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Interactive mode toggle animates smoothly between Sign In and Sign Up',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial State: Sign In
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);

    // 2. Tap Sign Up tab to trigger forward animation
    await tester.tap(find.text('Sign Up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // 3. Verify animated expansion into Sign Up mode
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Already have an account? Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(5));

    // 4. Tap Sign In tab to trigger reverse animation
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // 5. Verify animated collapse back to Sign In mode
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
