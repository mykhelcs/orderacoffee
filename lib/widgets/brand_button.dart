import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    this.trailing,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final String? trailing;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark ? AppColors.brandDark : AppColors.brandLight);
    final fg = foregroundColor ??
        (isDark ? AppColors.onBrandDark : AppColors.onBrandLight);

    final isEnabled = onPressed != null && !isLoading;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: trailing != null
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.figtree(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (trailing != null)
                        Text(
                          trailing!,
                          style: GoogleFonts.figtree(
                            color: fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
