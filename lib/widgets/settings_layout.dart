import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

class SettingsPageLayout extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const SettingsPageLayout({
    super.key,
    required this.children,
    this.maxWidth = 1120,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.icon,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withAlpha(232),
          border: Border(
            left: BorderSide(color: colorScheme.primary, width: 3),
            top: BorderSide(color: colorScheme.outlineVariant),
            right: BorderSide(color: colorScheme.outlineVariant),
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: colorScheme.surfaceContainerHigh.withAlpha(120),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.textTheme.titleSmall),
                          if (description != null)
                            Text(
                              description!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            for (var index = 0; index < children.length; index++) ...[
              Material(color: Colors.transparent, child: children[index]),
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: colorScheme.outlineVariant.withAlpha(90),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsResponsiveGrid extends StatelessWidget {
  final List<Widget> children;

  const SettingsResponsiveGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
