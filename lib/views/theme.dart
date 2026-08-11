import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeItem {
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;

  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
}

class ThemeView extends ConsumerWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final themeMode = ref.watch(
      themeSettingProvider.select((state) => state.themeMode),
    );
    final items = [
      ThemeModeItem(
        iconData: Icons.brightness_auto_rounded,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: Icons.light_mode_rounded,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: Icons.dark_mode_rounded,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.theme,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: AppGlassPanel(
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withAlpha(28),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.contrast_rounded,
                      color: context.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    appLocalizations.themeMode,
                    style: context.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  final List<Widget> choices = [
                    for (final item in items)
                      _ThemeModeChoice(
                        item: item,
                        isSelected: item.themeMode == themeMode,
                        onPressed: () {
                          ref
                              .read(themeSettingProvider.notifier)
                              .update(
                                (state) => state.copyWith(
                                  themeMode: item.themeMode,
                                ),
                              );
                        },
                      ),
                  ];
                  if (isNarrow) {
                    return Column(
                      children: choices
                          .separated(const SizedBox(height: 12))
                          .toList(),
                    );
                  }
                  return Row(
                    children: choices
                        .map<Widget>((item) => Expanded(child: item))
                        .separated(const SizedBox(width: 12))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeChoice extends StatelessWidget {
  final ThemeModeItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ThemeModeChoice({
    required this.item,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      isSelected: isSelected,
      radius: 22,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              item.iconData,
              color: isSelected
                  ? context.colorScheme.onPrimary
                  : context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(item.label, style: context.textTheme.titleMedium),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: isSelected
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey(true),
                    color: context.colorScheme.primary,
                  )
                : const SizedBox(
                    key: ValueKey(false),
                    width: 24,
                    height: 24,
                  ),
          ),
        ],
      ),
    );
  }
}
