import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/brand_button.dart';
import 'auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    try {
      await ref.read(authProvider.notifier).signUp(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Failure(\s*\([^)]*\))?:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo()),
                    const SizedBox(height: 24),
                    Text(
                      'Create Account',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: inkCol,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order ahead and earn stamps on every sip.',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        color: muteCol,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bad.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.bad.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.figtree(
                            color: AppColors.bad,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Full Name
                    Text(
                      'Full name',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Maria Clara',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    // Email
                    Text(
                      'Email address',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'maria@coughfee.ph',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!isValidEmail(v)) return 'Please enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Phone Number
                    Text(
                      'Phone number',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: '+63 912 345 6789',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone number is required';
                        if (!isValidPhone(v)) return 'Enter valid PH number (+63 9xx or 09xx)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Password
                    Text(
                      'Password',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // Confirm Password
                    Text(
                      'Confirm password',
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: inkCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSignUp(),
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    BrandButton(
                      label: 'Sign up',
                      isLoading: authState.isLoading,
                      onPressed: _handleSignUp,
                    ),
                    const SizedBox(height: 18),
                    // Switch to Log In
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: GoogleFonts.figtree(fontSize: 14, color: muteCol),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: Text(
                            'Log in',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: brandCol,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
