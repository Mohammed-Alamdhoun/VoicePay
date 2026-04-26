import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class BackgroundShapes extends StatelessWidget {
  final bool isDark;
  const BackgroundShapes({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top orange shape
        Positioned(
          top: -170,
          left: -120,
          child: IgnorePointer(
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark 
                    ? AppColors.primary.withOpacity(0.28)
                    : AppColors.primary.withOpacity(0.75),
              ),
            ),
          ),
        ),
        // Bottom blue shape
        Positioned(
          bottom: -220,
          right: -140,
          child: IgnorePointer(
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.secondary.withOpacity(0.20)
                    : AppColors.secondary.withOpacity(0.75),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
