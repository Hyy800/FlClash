import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return ColoredBox(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.72, -0.84),
            radius: 1.25,
            colors: [
              colorScheme.primary.withAlpha(isDark ? 48 : 38),
              colorScheme.secondary.withAlpha(isDark ? 20 : 18),
              Colors.transparent,
            ],
            stops: const [0, 0.34, 1],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, 0.96),
              radius: 1.05,
              colors: [
                colorScheme.tertiary.withAlpha(isDark ? 22 : 16),
                Colors.transparent,
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry borderRadius;

  const AppGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(28)
              : colorScheme.outlineVariant.withAlpha(150),
        ),
        borderRadius: borderRadius,
        color: colorScheme.surfaceContainerLowest.withAlpha(isDark ? 210 : 242),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(isDark ? 40 : 14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
