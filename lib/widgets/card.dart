import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';

import 'fade_box.dart';
import 'text.dart';

class CommonCardScope extends InheritedWidget {
  const CommonCardScope({super.key, required super.child});

  static bool isInside(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CommonCardScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(CommonCardScope oldWidget) => false;
}

class Info {
  final String label;
  final IconData? iconData;

  const Info({required this.label, this.iconData});
}

class InfoHeader extends StatelessWidget {
  final Info info;
  final List<Widget> actions;
  final EdgeInsets? padding;

  const InfoHeader({
    super.key,
    required this.info,
    this.padding,
    List<Widget>? actions,
  }) : actions = actions ?? const [];

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry nextPadding = (padding ?? baseInfoEdgeInsets);
    if (actions.isNotEmpty) {
      nextPadding = nextPadding.subtract(EdgeInsets.symmetric(vertical: 8.mAp));
    }
    return Padding(
      padding: nextPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 1,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (info.iconData != null) ...[
                  Icon(
                    info.iconData,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  flex: 1,
                  child: TooltipText(
                    text: Text(
                      info.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (actions.isNotEmpty)
            SizedBox(
              height: globalState.measure.titleSmallHeight + 16.ap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [...actions],
              ),
            ),
        ],
      ),
    );
  }
}

class CommonCard extends StatelessWidget {
  const CommonCard({
    super.key,
    bool? isSelected,
    this.type = CommonCardType.plain,
    this.onPressed,
    this.selectWidget,
    this.radius,
    required this.child,
    this.padding,
    this.enterAnimated = false,
    this.info,
    this.onLongPress,
    this.shape,
    this.isError = false,
  }) : isSelected = isSelected ?? false;

  final bool enterAnimated;
  final bool isSelected;
  final bool isError;
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final Widget? selectWidget;
  final Widget child;
  final EdgeInsets? padding;
  final Info? info;
  final CommonCardType type;
  final double? radius;
  final OutlinedBorder? shape;

  BorderSide _buildBorderSide(BuildContext context, Set<WidgetState> states) {
    final colorScheme = context.colorScheme;
    if (isError) {
      if (type == CommonCardType.filled) {
        return BorderSide(color: colorScheme.error);
      }
      final hoverColor = isSelected
          ? colorScheme.error.opacity80
          : colorScheme.error.opacity38;
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return BorderSide(color: hoverColor);
      }
      return BorderSide(
        color: isSelected
            ? colorScheme.error.opacity60
            : colorScheme.error.opacity30,
      );
    }
    if (type == CommonCardType.filled) {
      return BorderSide(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.outlineVariant.withAlpha(80),
      );
    }
    final hoverColor = isSelected
        ? colorScheme.primary.opacity80
        : colorScheme.primary.opacity60;
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed)) {
      return BorderSide(color: hoverColor);
    }
    return BorderSide(
      color: isSelected
          ? colorScheme.primary
          : colorScheme.outlineVariant.withAlpha(90),
    );
  }

  Color? _buildBackgroundColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.errorContainer.withAlpha(isSelected ? 220 : 145);
    }
    if (type == CommonCardType.filled) {
      if (isSelected) {
        return Color.alphaBlend(
          colorScheme.primary.withAlpha(25),
          colorScheme.surfaceContainerHigh,
        );
      }
      return colorScheme.surfaceContainerLow;
    }
    if (isSelected) {
      return Color.alphaBlend(
        colorScheme.primary.withAlpha(22),
        colorScheme.surfaceContainerLow,
      );
    }
    return colorScheme.surfaceContainerLow;
  }

  Color? _buildForegroundColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.error;
    }
    if (type == CommonCardType.filled) {
      if (isSelected) {
        return colorScheme.onSurface;
      }
      return colorScheme.onSurfaceVariant;
    }
    if (isSelected) {
      return colorScheme.onSurface;
    }
    return colorScheme.onSurfaceVariant;
  }

  Color? _buildIconColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.error;
    }
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    var childWidget = child;

    if (info != null) {
      childWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoHeader(
            padding: baseInfoEdgeInsets.copyWith(bottom: 0),
            info: info!,
          ),
          Flexible(flex: 1, child: child),
        ],
      );
    }

    if (selectWidget != null && isSelected) {
      final List<Widget> children = [];
      children.add(childWidget);
      children.add(Positioned.fill(child: selectWidget!));
      childWidget = Stack(children: children);
    }

    final colorScheme = context.colorScheme;
    final cardShape = (shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius ?? 20),
            ))
        .copyWith(side: _buildBorderSide(context, const <WidgetState>{}));
    final backgroundColor = _buildBackgroundColor(context)!;
    final foregroundColor = _buildForegroundColor(context)!;
    final card = AnimatedContainer(
      duration: midDuration,
      curve: Curves.easeOutCubic,
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: cardShape,
        shadows: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(30),
                  blurRadius: 12,
                  spreadRadius: -3,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
        child: InkWell(
          customBorder: cardShape,
          onLongPress: onLongPress,
          onTap: onPressed,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: IconTheme.merge(
              data: IconThemeData(color: _buildIconColor(context), size: 20),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foregroundColor),
                child: CommonCardScope(child: childWidget),
              ),
            ),
          ),
        ),
      ),
    );

    return switch (enterAnimated) {
      true => FadeScaleEnterBox(child: card),
      false => card,
    };
  }
}

class SelectIcon extends StatelessWidget {
  const SelectIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.inversePrimary,
      shape: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(5),
        child: const Icon(Icons.check_rounded, size: 16),
      ),
    );
  }
}

class SettingsBlock extends StatelessWidget {
  final String title;
  final List<Widget> settings;

  const SettingsBlock({super.key, required this.title, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          InfoHeader(info: Info(label: title)),
          CommonCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: settings),
          ),
        ],
      ),
    );
  }
}
