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
                        Color(0xFF171713),
                        Color(0xFF24211B),
                        Color(0xFF111419),
                      ]
                    : const [
                        Color(0xFFE8DFD1),
                        Color(0xFFD9D0C2),
                        Color(0xFFE7E9E7),
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
          color: isDark
              ? Colors.white.withAlpha(24)
              : Colors.white.withAlpha(150),
        ),
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHigh.withAlpha(isDark ? 224 : 214),
            colorScheme.surfaceContainerLow.withAlpha(isDark ? 210 : 198),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(isDark ? 96 : 42),
            blurRadius: 38,
            offset: const Offset(0, 18),
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
