import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF171714),
                        Color(0xFF1C1C19),
                        Color(0xFF151613),
                      ]
                    : const [
                        Color(0xFFF3EEE6),
                        Color(0xFFE8E1D7),
                        Color(0xFFEEF0ED),
                      ],
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.82, -0.78),
                  radius: 0.92,
                  colors: [
                    const Color(0xFFD99B5E).withAlpha(isDark ? 26 : 58),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.86],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.92, 0.82),
                  radius: 0.78,
                  colors: [
                    colorScheme.primary.withAlpha(isDark ? 26 : 34),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.9],
                ),
              ),
            ),
          ),
          child,
        ],
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
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(isDark ? 105 : 125),
        ),
        borderRadius: borderRadius,
        color: colorScheme.surfaceContainerLow.withAlpha(isDark ? 238 : 232),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(isDark ? 42 : 24),
            blurRadius: 24,
            spreadRadius: -4,
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
