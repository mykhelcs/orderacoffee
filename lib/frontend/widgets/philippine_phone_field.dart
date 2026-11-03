import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:orderacoffee/core/philippine_phone_input_formatter.dart';
import 'package:orderacoffee/frontend/theme/theme.dart';

/// A custom Philippine mobile phone input field.
///
/// Features:
/// - Statically rendered '+63' prefix badge with phone icon and vertical divider.
/// - Dynamic 1.5-second brand highlight on the badge when '0' is stripped from '09'.
/// - Strict 10-digit enforcement starting with 9 using [PhilippinePhoneInputFormatter].
class PhilippinePhoneField extends StatefulWidget {
  const PhilippinePhoneField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  @override
  State<PhilippinePhoneField> createState() => _PhilippinePhoneFieldState();
}

class _PhilippinePhoneFieldState extends State<PhilippinePhoneField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;
  late final PhilippinePhoneInputFormatter _formatter;

  @override
  void initState() {
    super.initState();
    // 1.5-second total duration for the brand highlight
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Quick ramp up (0 to 150ms) then smooth fade out (150ms to 1500ms)
    _highlightAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 85,
      ),
    ]).animate(_highlightController);

    _formatter = PhilippinePhoneInputFormatter(
      onZeroStripped: _triggerHighlight,
    );
  }

  void _triggerHighlight() {
    if (mounted) {
      _highlightController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;
    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, _) {
        final highlightValue = _highlightAnimation.value;
        final badgeBg = Color.lerp(
          Colors.transparent,
          brandCol.withValues(alpha: 0.18),
          highlightValue,
        )!;
        final iconCol = Color.lerp(muteCol, brandCol, highlightValue)!;
        final prefixTextCol = Color.lerp(inkCol, brandCol, highlightValue)!;
        final dividerCol = Color.lerp(lineCol, brandCol, highlightValue)!;

        return TextFormField(
          key: const Key('philippine_phone_input_field'),
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.phone,
          textInputAction: widget.textInputAction,
          inputFormatters: [_formatter],
          onChanged: widget.onChanged,
          onSaved: widget.onSaved,
          validator: widget.validator ?? _defaultValidator,
          style: GoogleFonts.figtree(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: inkCol,
          ),
          decoration: InputDecoration(
            hintText: '9XX XXX XXXX',
            hintStyle: GoogleFonts.figtree(
              color: muteCol.withValues(alpha: 0.6),
              fontSize: 15,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            prefixIcon: Container(
              key: const Key('philippine_phone_prefix_badge'),
              margin: const EdgeInsets.only(left: 6, right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
                border: highlightValue > 0.05
                    ? Border.all(
                        color: brandCol.withValues(alpha: 0.35 * highlightValue),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 18,
                    color: iconCol,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+63',
                    style: GoogleFonts.figtree(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: prefixTextCol,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 18,
                    color: dividerCol,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final rawDigits = value.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.length != 10 || !rawDigits.startsWith('9')) {
      return 'Enter a valid 10-digit number starting with 9';
    }
    return null;
  }
}
