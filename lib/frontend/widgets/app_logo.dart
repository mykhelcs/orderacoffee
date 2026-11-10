import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The official CafeGO brand logo featuring a handcrafted artisan emblem
/// and premium serif typography.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.fontSize = 24,
    this.showSubtitle = false,
    this.textColor,
  });

  final double fontSize;
  final bool showSubtitle;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Brand color palette
    final primaryAmber = isDark ? const Color(0xFFD4A373) : const Color(0xFF5A3825);
    final accentTerracotta = isDark ? const Color(0xFFE29578) : const Color(0xFF8B5A3E);
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface;

    final emblemSize = fontSize * 1.35;
    final iconSize = fontSize * 0.72;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handcrafted Artisan Coffee Emblem
            Container(
              width: emblemSize,
              height: emblemSize,
              margin: EdgeInsets.only(right: fontSize * 0.35),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [accentTerracotta, primaryAmber]
                      : [primaryAmber, accentTerracotta],
                ),
                borderRadius: BorderRadius.circular(fontSize * 0.38),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? primaryAmber : accentTerracotta).withValues(alpha: 0.3),
                    blurRadius: fontSize * 0.3,
                    offset: Offset(0, fontSize * 0.08),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.local_cafe_rounded,
                  size: iconSize,
                  color: isDark ? const Color(0xFF1E1715) : Colors.white,
                ),
              ),
            ),

            // Typography: CafeGO with distinctive brand styling
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Cafe',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: effectiveTextColor,
                    ),
                  ),
                  TextSpan(
                    text: 'GO',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: primaryAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showSubtitle)
          Padding(
            padding: EdgeInsets.only(
              left: emblemSize + (fontSize * 0.35) + 2,
              top: 2,
            ),
            child: Text(
              'Your daily comfort brew',
              style: GoogleFonts.playfairDisplay(
                fontSize: fontSize * 0.45,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
                color: effectiveTextColor.withValues(alpha: 0.75),
              ),
            ),
          ),
      ],
    );
  }
}
