import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/order.dart';

enum StepState { done, current, future }

class StepTracker extends StatelessWidget {
  const StepTracker({
    super.key,
    required this.status,
  });

  final OrderStatus status;

  static const List<OrderStatus> _trackedSteps = [
    OrderStatus.received,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _trackedSteps.indexOf(status);

    return Column(
      children: List.generate(_trackedSteps.length, (index) {
        final step = _trackedSteps[index];
        final label = kOrderLabels[step.name] ?? step.name;

        StepState stepState;
        if (status == OrderStatus.completed) {
          stepState = StepState.done;
        } else if (currentIndex < 0) {
          stepState = StepState.future;
        } else if (index < currentIndex) {
          stepState = StepState.done;
        } else if (index == currentIndex) {
          stepState = StepState.current;
        } else {
          stepState = StepState.future;
        }

        final isLast = index == _trackedSteps.length - 1;

        return StepItemWidget(
          label: label,
          state: stepState,
          isLast: isLast,
        );
      }),
    );
  }
}

class StepItemWidget extends StatelessWidget {
  const StepItemWidget({
    super.key,
    required this.label,
    required this.state,
    required this.isLast,
  });

  final String label;
  final StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final lineCol = isDark ? AppColors.lineDark : AppColors.lineLight;
    final inkCol = isDark ? AppColors.inkDark : AppColors.inkLight;
    final muteCol = isDark ? AppColors.muteDark : AppColors.muteLight;
    final brandCol = isDark ? AppColors.brandDark : AppColors.brandLight;

    Color circleBg;
    Color circleBorder;
    Color textColor;
    FontWeight fontWeight;

    switch (state) {
      case StepState.done:
        circleBg = brandCol;
        circleBorder = brandCol;
        textColor = inkCol;
        fontWeight = FontWeight.w500;
        break;
      case StepState.current:
        circleBg = AppColors.crema;
        circleBorder = AppColors.crema;
        textColor = inkCol;
        fontWeight = FontWeight.w600;
        break;
      case StepState.future:
        circleBg = isDark ? AppColors.bgDark : AppColors.bgLight;
        circleBorder = lineCol;
        textColor = muteCol;
        fontWeight = FontWeight.w400;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left indicator column
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: circleBorder, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: lineCol,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Label text
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
              child: Text(
                label,
                style: GoogleFonts.figtree(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
