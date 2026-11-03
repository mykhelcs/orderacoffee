import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/core/philippine_phone_input_formatter.dart';
import 'package:orderacoffee/frontend/widgets/philippine_phone_field.dart';
import 'auth_provider.dart';

enum AuthMode { signIn, signUp }

/// Custom wavy clipper for the coffee image header matching the reference UI
class CoffeeHeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 45);

    // Smooth organic wave dipping down towards the right
    final firstControlPoint = Offset(size.width * 0.35, size.height - 85);
    final firstEndPoint = Offset(size.width * 0.65, size.height - 20);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.85, size.height + 15);
    final secondEndPoint = Offset(size.width, size.height - 35);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialMode = AuthMode.signIn,
  });

  final AuthMode initialMode;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _isLoading = false;

  // Mode Animation Controller (0.0 = Sign In, 1.0 = Sign Up)
  late final AnimationController _modeController;
  late final Animation<double> _springAnimation;
  late final Animation<double> _swirlAnimation;

  // Button interactive press bounce controller
  late final AnimationController _buttonBounceController;
  late final Animation<double> _buttonScaleAnimation;



  @override
  void initState() {
    super.initState();

    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: widget.initialMode == AuthMode.signUp ? 1.0 : 0.0,
    );

    _springAnimation = CurvedAnimation(
      parent: _modeController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOutCubic,
    );

    // Playful coffee swirl / rotation pulse animation during tab switch
    _swirlAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_modeController);

    // Interactive button press bounce
    _buttonBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _buttonBounceController,
        curve: Curves.easeOut,
      ),
    );

    // Populate pending registration details if returning from email change
    final authState = ref.read(authProvider);
    final pending = authState.pendingRegistration;
    if (pending != null) {
      _nameController.text = pending['name'] ?? '';
      final raw = (pending['phone'] ?? '').replaceFirst('+63', '').trim();
      _phoneController.text = PhilippinePhoneInputFormatter.formatDigits(raw);
      _passwordController.text = pending['password'] ?? '';
      _confirmPasswordController.text = pending['password'] ?? '';
      _emailController.text = authState.pendingEmail ?? '';
    }
  }

  @override
  void dispose() {
    _modeController.dispose();
    _buttonBounceController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchToMode(AuthMode mode) {
    setState(() => _errorMessage = null);
    if (mode == AuthMode.signUp) {
      _modeController.forward();
    } else {
      _modeController.reverse();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final isSignUpMode = _modeController.value > 0.5;

    if (isSignUpMode &&
        _passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      if (isSignUpMode) {
        // Sign Up submission
        final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
        final formattedPhone =
            phoneDigits.isNotEmpty ? '+63 $phoneDigits' : '+63 900 000 0000';

        await ref.read(authProvider.notifier).initiateSignUp(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phone: formattedPhone,
              password: _passwordController.text,
            );
        if (mounted) {
          context.go('/verify-email');
        }
      } else {
        // Sign In submission
        await ref.read(authProvider.notifier).signIn(
              _emailController.text.trim(),
              _passwordController.text,
            );
        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(
                RegExp(r'^[A-Za-z]+Failure(\s*\([^)]*\))?:\s*'),
                '',
              );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E2728),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFF7F1EB),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address to receive password reset instructions.',
              style: GoogleFonts.figtree(
                color: const Color(0xFFD4C8C2),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5DDD8),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFF2C2223)),
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: Color(0xFF6E5D5E)),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.figtree(color: const Color(0xFFD4C8C2)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B1516),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                await ref.read(authProvider.notifier).resetPassword(email);
                if (mounted && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Password reset instructions sent to your email.'),
                      backgroundColor: Color(0xFF3F3536),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Send Reset Link',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF342B2B);
    const latteFieldColor = Color(0xFFE5DDD8);
    const textDarkColor = Color(0xFF2C2223);
    const hintTextColor = Color(0xFF6E5D5E);
    const buttonDarkColor = Color(0xFF1B1516);
    const creamTextColor = Color(0xFFF7F1EB);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _modeController,
        builder: (context, child) {
          final modeVal = _springAnimation.value;
          final isSignUpActive = _modeController.value > 0.5;

          // Interpolated header height: 285 in Sign In mode, 215 in Sign Up mode
          final headerHeight = lerpDouble(285.0, 215.0, modeVal)!;

          // Subtle coffee swirl pulse rotation during transition
          final swirlRotation = _swirlAnimation.value * 0.04;
          final swirlScale = 1.0 + (_swirlAnimation.value * 0.05);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Top wavy coffee splash image header with animated height & swirl
                ClipPath(
                  clipper: CoffeeHeaderWaveClipper(),
                  child: SizedBox(
                    height: headerHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.scale(
                          scale: swirlScale,
                          child: Transform.rotate(
                            angle: swirlRotation,
                            child: Image.asset(
                              'assets/images/coffee_splash.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0.0, 0.4),
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF231A19),
                                  child: const Center(
                                    child: Icon(
                                      Icons.coffee_rounded,
                                      size: 64,
                                      color: Color(0xFFD4A373),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Soft vignette overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.25),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Interactive Animated Tabs: Sign In | Sign Up
                        _buildInteractiveTabs(modeVal, creamTextColor),

                        // Animated "Create Account" label for Sign Up mode
                        if (modeVal > 0.001)
                          ClipRect(
                          child: Align(
                            alignment: Alignment.center,
                            heightFactor: modeVal.clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: modeVal.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 14.0),
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: creamTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Error message banner if any
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.figtree(
                                  color: const Color(0xFFFFB3B3),
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        // ─── 1. Full Name field (Sign Up only) ───────────────
                        if (modeVal > 0.001)
                          ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: modeVal.clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: modeVal.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 14.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: latteFieldColor,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 2),
                                  child: TextFormField(
                                    controller: _nameController,
                                    style: GoogleFonts.figtree(
                                      color: textDarkColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Maria Clara',
                                      labelText: 'Full Name',
                                      labelStyle: GoogleFonts.figtree(
                                          color: hintTextColor, fontSize: 13),
                                      hintStyle: GoogleFonts.figtree(
                                        color: hintTextColor
                                            .withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                    validator: (v) {
                                      if (_modeController.value > 0.5 &&
                                          (v == null || v.trim().isEmpty)) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ─── 2. Email field (Both modes) ─────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: latteFieldColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 2),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.figtree(
                              color: textDarkColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: isSignUpActive
                                  ? 'maria@coughfee.ph'
                                  : 'Email',
                              labelText: 'Email',
                              labelStyle: GoogleFonts.figtree(
                                  color: hintTextColor, fontSize: 13),
                              hintStyle: GoogleFonts.figtree(
                                color: hintTextColor.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!v.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ─── 3. Phone field (Sign Up only) ───────────────────
                        if (modeVal > 0.001)
                          ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: modeVal.clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: modeVal.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 14.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: latteFieldColor,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: PhilippinePhoneField(
                                    controller: _phoneController,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ─── 4. Password field (Both modes) ──────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: latteFieldColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 2),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.figtree(
                              color: textDarkColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: isSignUpActive
                                  ? 'At least 6 characters'
                                  : 'Password',
                              labelText: 'Password',
                              labelStyle: GoogleFonts.figtree(
                                  color: hintTextColor, fontSize: 13),
                              hintStyle: GoogleFonts.figtree(
                                color: hintTextColor.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: hintTextColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (isSignUpActive && v.length < 6) {
                                return 'Must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                        ),

                        // ─── 5. Confirm Password field (Sign Up only) ────────
                        if (modeVal > 0.001)
                          ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: modeVal.clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: modeVal.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 14.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: latteFieldColor,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 2),
                                  child: TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: GoogleFonts.figtree(
                                      color: textDarkColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Re-enter your password',
                                      labelText: 'Confirm Password',
                                      labelStyle: GoogleFonts.figtree(
                                          color: hintTextColor, fontSize: 13),
                                      hintStyle: GoogleFonts.figtree(
                                        color: hintTextColor
                                            .withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: hintTextColor,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword);
                                        },
                                      ),
                                    ),
                                    validator: (v) {
                                      if (_modeController.value > 0.5) {
                                        if (v == null || v.isEmpty) {
                                          return 'Please confirm password';
                                        }
                                        if (v != _passwordController.text) {
                                          return 'Passwords do not match';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ─── Forgot Password Link (Sign In only) ─────────────
                        ClipRect(
                          child: Align(
                            alignment: Alignment.center,
                            heightFactor: (1.0 - modeVal).clamp(0.0, 1.0),
                            child: Opacity(
                              opacity: (1.0 - modeVal).clamp(0.0, 1.0),
                              child: GestureDetector(
                                onTap: _showForgotPasswordDialog,
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: creamTextColor.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: lerpDouble(24.0, 16.0, modeVal)!),

                        // ─── Interactive Bouncy Submit Button ────────────────
                        GestureDetector(
                          onTapDown: (_) =>
                              _buttonBounceController.forward(),
                          onTapUp: (_) {
                            _buttonBounceController.reverse();
                            _handleSubmit();
                          },
                          onTapCancel: () =>
                              _buttonBounceController.reverse(),
                          child: ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: Container(
                              width: lerpDouble(170.0, 200.0, modeVal)!,
                              height: 48,
                              decoration: BoxDecoration(
                                color: buttonDarkColor,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(
                                        scale: anim,
                                        child: FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        ),
                                      ),
                                      child: Text(
                                        isSignUpActive
                                            ? 'Sign up'
                                            : 'Login',
                                        key: ValueKey(isSignUpActive),
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: creamTextColor,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ─── Bottom Mode Switch Prompt ───────────────────────
                        GestureDetector(
                          onTap: () {
                            if (isSignUpActive) {
                              _switchToMode(AuthMode.signIn);
                            } else {
                              _switchToMode(AuthMode.signUp);
                            }
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              isSignUpActive
                                  ? 'Already have an account? Sign In'
                                  : "Don't have an account yet?",
                              key: ValueKey(isSignUpActive),
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: creamTextColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Interactive sliding tab bar for [Sign In] and [Sign Up]
  Widget _buildInteractiveTabs(double modeVal, Color creamTextColor) {
    return Center(
      child: SizedBox(
        width: 230,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sign In Tab Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _switchToMode(AuthMode.signIn),
                  child: Container(
                    width: 95,
                    alignment: Alignment.center,
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: modeVal < 0.5
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: modeVal < 0.5
                            ? creamTextColor
                            : creamTextColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),

                // Sign Up Tab Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _switchToMode(AuthMode.signUp),
                  child: Container(
                    width: 95,
                    alignment: Alignment.center,
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: modeVal >= 0.5
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: modeVal >= 0.5
                            ? creamTextColor
                            : creamTextColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Animated Underline indicator that slides across
            SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Positioned(
                    left: lerpDouble(12.0, 142.0, modeVal)!,
                    child: Container(
                      height: 2.5,
                      width: 70,
                      decoration: BoxDecoration(
                        color: creamTextColor,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
