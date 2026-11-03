import 'package:flutter/material.dart';
import 'login_screen.dart';

/// SignUpScreen delegates to the interactive [LoginScreen] with [AuthMode.signUp]
/// selected by default, preserving direct route navigation and test compatibility.
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen(initialMode: AuthMode.signUp);
  }
}
