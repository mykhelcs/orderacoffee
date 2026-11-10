import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/core/philippine_phone_input_formatter.dart';
import 'package:orderacoffee/frontend/widgets/philippine_phone_field.dart';
import 'auth_provider.dart';

enum AuthMode { signIn, signUp }

/// Renders the official 4-color Google 'G' logo.
class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.21;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // 1. Red top arc (#EA4335)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      rect,
      -math.pi * 0.80,
      math.pi * 0.56,
      false,
      paint,
    );

    // 2. Yellow left arc (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      rect,
      math.pi * 0.78,
      math.pi * 0.44,
      false,
      paint,
    );

    // 3. Green bottom arc (#34A853)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      rect,
      math.pi * 0.22,
      math.pi * 0.58,
      false,
      paint,
    );

    // 4. Blue right arc + crossbar (#4285F4)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      rect,
      -math.pi * 0.04,
      math.pi * 0.28,
      false,
      paint,
    );

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx - size.width * 0.02,
        center.dy - strokeWidth * 0.48,
        size.width - strokeWidth * 0.05,
        center.dy + strokeWidth * 0.48,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
          final isStaff = ref.read(authProvider).isAdmin ||
              ref.read(authProvider).profile?.role == 'staff';
          context.go(isStaff ? '/admin' : '/');
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

  Future<void> _handleGoogleSignIn() async {
    setState(() => _errorMessage = null);

    // Open the persistent Gmail login connection dialog directly so it stays open
    // and always displays the Gmail email input without closing prematurely.
    final selectedAccount = await _showGmailLoginPopup();
    if (selectedAccount == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle(
            fallbackEmail: selectedAccount['email'],
            fallbackName: selectedAccount['name'],
          );
      if (mounted) {
        context.go('/');
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString().replaceFirst(
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

  Future<Map<String, String>?> _showGmailLoginPopup() async {
    final gmailController = TextEditingController(
      text: _emailController.text.contains('@')
          ? _emailController.text.trim()
          : '',
    );
    final nameController = TextEditingController();
    String? dialogError;

    const availableAccounts = <Map<String, String>>[
      {
        'name': 'Glenn Mykhel',
        'email': 'glennmykhel@gmail.com',
      },
      {
        'name': 'Glenn Mykhel Gulfan',
        'email': 'gglennmykhel@gmail.com',
      },
      {
        'name': 'Ranela Esgana',
        'email': 'ranelaesgana@gmail.com',
      },
      {
        'name': 'Sean Cole',
        'email': 'rane111605@gmail.com',
      },
    ];

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              key: const Key('gmail_popup_dialog'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Official 4-color Google 'G' Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: const GoogleLogoIcon(size: 20),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Sign in with Google',
                              style: GoogleFonts.figtree(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF202124),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Choose an account',
                        style: GoogleFonts.figtree(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF202124),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'to continue to COUGHFEE',
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          color: const Color(0xFF5F6368),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Selectable Google Accounts List
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < availableAccounts.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                              InkWell(
                                key: Key('google_account_option_$i'),
                                borderRadius: BorderRadius.vertical(
                                  top: i == 0
                                      ? const Radius.circular(14)
                                      : Radius.zero,
                                  bottom: i == availableAccounts.length - 1
                                      ? const Radius.circular(14)
                                      : Radius.zero,
                                ),
                                onTap: () {
                                  Navigator.pop(ctx, {
                                    'email': availableAccounts[i]['email']!,
                                    'name': availableAccounts[i]['name']!,
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: const Color(0xFF1A73E8),
                                        child: Text(
                                          availableAccounts[i]['name']![0]
                                              .toUpperCase(),
                                          style: GoogleFonts.figtree(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              availableAccounts[i]['name']!,
                                              style: GoogleFonts.figtree(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF202124),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              availableAccounts[i]['email']!,
                                              style: GoogleFonts.figtree(
                                                fontSize: 12,
                                                color: const Color(0xFF5F6368),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF5F6368),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Or use another Gmail account:',
                        style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5F6368),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (dialogError != null) ...[
                        Text(
                          dialogError!,
                          style: GoogleFonts.figtree(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        key: const Key('gmail_popup_email_field'),
                        controller: gmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Color(0xFF202124)),
                        decoration: InputDecoration(
                          labelText: 'Email or Gmail address',
                          hintText: 'you@gmail.com',
                          labelStyle: const TextStyle(color: Color(0xFF5F6368)),
                          hintStyle: const TextStyle(color: Color(0xFF9AA0A6)),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          isDense: true,
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            color: Color(0xFF4285F4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A73E8),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('gmail_popup_name_field'),
                        controller: nameController,
                        style: const TextStyle(color: Color(0xFF202124)),
                        decoration: InputDecoration(
                          labelText: 'Full Name (optional)',
                          hintText: 'Your Name',
                          labelStyle: const TextStyle(color: Color(0xFF5F6368)),
                          hintStyle: const TextStyle(color: Color(0xFF9AA0A6)),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          isDense: true,
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF5F6368),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A73E8),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.figtree(
                                color: const Color(0xFF5F6368),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const Key('gmail_popup_continue_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(110, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              final email = gmailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setDialogState(() {
                                  dialogError =
                                      'Please enter or select a Gmail address';
                                });
                                return;
                              }
                              final name = nameController.text.trim().isNotEmpty
                                  ? nameController.text.trim()
                                  : email.split('@').first;
                              Navigator.pop(ctx, {
                                'email': email,
                                'name': name,
                              });
                            },
                            child: Text(
                              'Continue',
                              style: GoogleFonts.figtree(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
              minimumSize: const Size(140, 44),
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

    final authState = ref.watch(authProvider);
    final isGoogleLastUsed = authState.isGoogleLastUsed;

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

                        // ─── Sign in with Google + Upper-Right "Last used" Badge ─
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: creamTextColor.withValues(alpha: 0.22),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: GoogleFonts.figtree(
                                  fontSize: 13,
                                  color: creamTextColor.withValues(alpha: 0.65),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: creamTextColor.withValues(alpha: 0.22),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              key: const Key('google_sign_in_button'),
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: latteFieldColor,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isGoogleLastUsed
                                        ? const Color(0xFFD4A373)
                                        : Colors.white.withValues(alpha: 0.25),
                                    width: isGoogleLastUsed ? 1.8 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.28),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const GoogleLogoIcon(size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        'Sign in with Google',
                                        style: GoogleFonts.figtree(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: textDarkColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Upper-right container containing "Last used"
                            if (isGoogleLastUsed)
                              Positioned(
                                top: -10,
                                right: 14,
                                child: Container(
                                  key: const Key('google_last_used_badge'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B1516),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFD4A373),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Last used',
                                    style: GoogleFonts.figtree(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF7F1EB),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ─── Admin Quick Demo Sign In ─────────────────────────
                        if (!isSignUpActive) ...[
                          OutlinedButton.icon(
                            key: const Key('adminDemoLoginButton'),
                            onPressed: () async {
                              setState(() {
                                _emailController.text = 'admin@cafego.ph';
                                _passwordController.text = 'Admin@CafeGo2024!';
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              try {
                                await ref.read(authProvider.notifier).signInAsAdmin();
                                if (!mounted) return;
                                context.go('/admin');
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _errorMessage = e.toString());
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFD4A373).withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: Color(0xFFD4A373),
                            ),
                            label: Text(
                              'Sign in as Admin Demo',
                              style: GoogleFonts.figtree(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFD4A373),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

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
