import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.bricolageGrotesque(
      fontSize: 22,
      fontWeight: FontWeight.w800,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'cough',
          style: style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          'fee',
          style: style.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
