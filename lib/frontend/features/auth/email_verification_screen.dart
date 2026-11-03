import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/frontend/theme/theme.dart';
import 'package:orderacoffee/frontend/widgets/app_logo.dart';
import 'package:orderacoffee/frontend/widgets/brand_button.dart';
import 'auth_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  static const int _codeLength = 6;
  static const int _cooldownSeconds = 30;

  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_codeLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = _cooldownSeconds;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentCode =>
      _controllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerify() async {
    final code = _currentCode;
    if (code.length < _codeLength) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the code');
      return;
    }

    setState(() => _errorMessage = null);

    try {
      final success = await ref
          .read(authProvider.notifier)
          .confirmEmailVerification(code);
      if (success && mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e
              .toString()
              .replaceFirst(RegExp(r'^[A-Za-z]+Failure(\s*\([^)]*\))?:\s*'), '');
        });
      }
    }
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0) return;
    setState(() => _errorMessage = null);

    try {
      await ref.read(authProvider.notifier).resendVerificationCode();
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new 6-digit code has been sent to your email.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e
              .toString()
              .replaceFirst(RegExp(r'^[A-Za-z]+Failure(\s*\([^)]*\))?:\s*'), '');
        });
      }
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted multiple characters
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < _codeLength; i++) {
          if (i < digits.length) {
            _controllers[i].text = digits[i];
          }
        }
        final nextFocusIndex = (digits.length < _codeLength)
            ? digits.length
            : _codeLength - 1;
        _focusNodes[nextFocusIndex].requestFocus();
        if (digits.length >= _codeLength) {
          _handleVerify();
        }
        return;
      }
    }

    if (value.isNotEmpty) {
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentCode.length == _codeLength) {
          _handleVerify();
        }
      }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
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
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final cardCol = isDark ? AppColors.cardDark : AppColors.cardLight;

    final authState = ref.watch(authProvider);
    final pendingEmail = authState.pendingEmail ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo()),
                  const SizedBox(height: 24),

                  // Mail envelope badge icon
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: brandCol.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 34,
                        color: brandCol,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'Verify your email',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: inkCol,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'We sent a 6-digit authentication code to\n$pendingEmail',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      color: muteCol,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Inbox delivery notice banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: brandCol.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: brandCol.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 20,
                          color: brandCol,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please check your email inbox or spam folder for your 6-digit code.',
                            style: GoogleFonts.figtree(
                              fontSize: 13,
                              color: inkCol,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Error message container
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bad.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.bad.withValues(alpha: 0.3),
                        ),
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
                    const SizedBox(height: 18),
                  ],

                  // 6 Digit Input Cells
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_codeLength, (index) {
                      return SizedBox(
                        width: 46,
                        height: 56,
                        child: RawKeyboardListener(
                          focusNode: FocusNode(),
                          onKey: (event) => _onKeyDown(index, event),
                          child: TextFormField(
                            key: Key('otp_box_$index'),
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.figtree(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: inkCol,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: cardCol,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: lineCol),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: lineCol),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: brandCol,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (val) => _onDigitChanged(index, val),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Verify & Continue Button
                  BrandButton(
                    label: 'Verify and Continue',
                    isLoading: authState.isVerifying,
                    onPressed: _handleVerify,
                  ),
                  const SizedBox(height: 20),

                  // Resend code wrap with cooldown timer
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: GoogleFonts.figtree(
                          fontSize: 14,
                          color: muteCol,
                        ),
                      ),
                      if (_secondsRemaining > 0)
                        Text(
                          'Resend in ${_secondsRemaining}s',
                          style: GoogleFonts.figtree(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: muteCol,
                          ),
                        )
                      else
                        GestureDetector(
                          key: const Key('resend_code_button'),
                          onTap: _handleResend,
                          child: Text(
                            'Resend code',
                            style: GoogleFonts.figtree(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: brandCol,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Back to Sign Up / Change email
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(authProvider.notifier).prepareChangeEmail();
                        context.go('/signup');
                      },
                      child: Text(
                        'Change email address',
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muteCol,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
