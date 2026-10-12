import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

class AccessibleButton extends StatelessWidget {
  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppConstants.touchTargetMinSize, AppConstants.buttonMinHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.paleBlue;
        }
        return primary ? AppColors.yellow : AppColors.surface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.muted;
        }
        return AppColors.navy;
      }),
      side: WidgetStatePropertyAll(
        BorderSide(color: primary ? AppColors.yellow : AppColors.border),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );

    final content = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (icon != null) Icon(icon, size: 22),
        Text(label, textAlign: TextAlign.center),
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          child: primary
              ? FilledButton(
                  onPressed: onPressed,
                  style: style,
                  child: content,
                )
              : OutlinedButton(
                  onPressed: onPressed,
                  style: style,
                  child: content,
                ),
        ),
      ),
    );
  }
}
