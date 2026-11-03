import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.fontSize = 24,
    this.showSubtitle = false,
  });

  final double fontSize;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFFD4A373) : const Color(0xFF5A3825);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Coffee cup icon
            Container(
              padding: const EdgeInsets.all(5),
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.coffee_rounded,
                size: fontSize * 0.75,
                color: primaryColor,
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Cafe',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: onSurface,
                    ),
                  ),
                  TextSpan(
                    text: 'GO',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showSubtitle)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 1),
            child: Text(
              'Your daily comfort brew',
              style: GoogleFonts.playfairDisplay(
                fontSize: fontSize * 0.45,
                fontStyle: FontStyle.italic,
                color: onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
      ],
    );
  }
}
