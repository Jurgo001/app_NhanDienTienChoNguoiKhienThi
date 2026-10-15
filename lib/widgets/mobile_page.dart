import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import 'accessible_button.dart';

/// Shared mobile page layout, including scrolling at large accessibility sizes.
class MobilePage extends StatelessWidget {
  const MobilePage({
    super.key,
    required this.children,
    this.background = AppColors.canvas,
    this.backLabel,
  });

  final List<Widget> children;
  final Color background;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (backLabel != null) ...[
                        Tooltip(
                          message: 'Quay lại',
                          child: AccessibleButton(
                            label: backLabel!,
                            icon: Icons.arrow_back,
                            primary: false,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the entire navigator within a phone-sized viewport on desktop.
class MobileViewport extends StatelessWidget {
  const MobileViewport({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 600;
        final width = desktop ? 390.0 : constraints.maxWidth;
        final height = desktop
            ? (constraints.maxHeight - 32).clamp(0.0, 844.0)
            : constraints.maxHeight;
        return ColoredBox(
          color: const Color(0xFFE8EDF2),
          child: Center(
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(desktop ? 20 : 0),
                boxShadow: desktop
                    ? const [
                        BoxShadow(
                          color: Color(0x180F1F36),
                          blurRadius: 32,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(width, height),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
