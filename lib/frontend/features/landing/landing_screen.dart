import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';



class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // 3 seconds animation to match the 3-second loading requirement
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _navigationTimer = Timer(const Duration(seconds: 3), _proceed);
  }

  void _proceed() {
    if (!mounted) return;
    context.go('/login');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1715),
      body: GestureDetector(
        onTap: _proceed, // Tap anywhere to skip if desired
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full screen background coffee splash image
            Image.asset(
              'assets/images/coffee_splash.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF281E1C),
                  child: const Center(
                    child: Icon(
                      Icons.coffee_rounded,
                      size: 80,
                      color: Color(0xFFD4A373),
                    ),
                  ),
                );
              },
            ),

            // Subtle dark overlay to match the reference landing page
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Content: "CafeGO" and "Your daily comfort brew"
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 90),
                    // "CafeGO" title
                    Text(
                      'CafeGO',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.0,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // "Your daily comfort brew" subtitle in elegant script/italic
                    Text(
                      'Your daily comfort brew',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFF7F1EB),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // 3-second loader at bottom
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated smooth progress line
                          AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return Container(
                                width: 140,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 140 * _progressController.value,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2D6CF),
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Brewing your experience...',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFFE2D6CF).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
