import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.a && next.c) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(storeActionProvider.notifier)
            .savePreferencesDebounce();
      }
    });
    ref.listenManual(globalOverwriteProfileIdProvider, (prev, next) {
      if (prev != next) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true, force: true);
      }
    });
    ref.listenManual(disabledProfileIdsProvider, (prev, next) {
      if (prev != next) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true, force: true);
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(proxiesActionProvider.notifier)
            .updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      final isStart = ref.read(isStartProvider);
      if (prev != next && isStart) {
        debouncer.call(FunctionTag.suspend, () async {
          if (next == true) {
            await coreController.stopListener();
          } else {
            await coreController.startListener();
          }
          ref.read(checkIpNumProvider.notifier).add();
        });
      }
    });
    if (system.isMacOS) {
      ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
        if (prev == next) {
          return;
        }
        if (next.a == true && next.b == true) {
          macOS?.updateDns(false);
        } else {
          macOS?.updateDns(true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      permissions.check();
      render?.resume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ref = globalState.container;
        ref.read(setupActionProvider.notifier).tryCheckIp();
        if (system.isAndroid) {
          ref.read(coreActionProvider.notifier).tryStartCore();
        }
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.container.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerStatefulWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  @override
  ConsumerState<AppSidebarContainer> createState() =>
      _AppSidebarContainerState();
}

class _AppSidebarContainerState extends ConsumerState<AppSidebarContainer> {
  bool _isExpanded = true;

  void _updateSideBarWidth(double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return widget.child;
    }
    final currentIndex = navigationState.currentIndex;
    final railWidth = _isExpanded ? 214.0 : 76.0;
    return SafeArea(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: railWidth,
            margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
            padding: EdgeInsets.fromLTRB(
              _isExpanded ? 12 : 9,
              18,
              _isExpanded ? 12 : 9,
              14,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerLowest.withAlpha(218),
              border: Border.all(
                color: Theme.brightnessOf(context) == Brightness.dark
                    ? Colors.white.withAlpha(26)
                    : Colors.white.withAlpha(205),
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: context.colorScheme.shadow.withAlpha(18),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _AppCommandBrand(showLabel: _isExpanded),
                const SizedBox(height: 22),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: HiddenBarScrollBehavior(),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: navigationItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = navigationItems[index];
                        return _AppRailItem(
                          item: item,
                          isSelected: currentIndex == index,
                          showLabel: _isExpanded,
                          onPressed: () => _handleToPage(item.label),
                        );
                      },
                    ),
                  ),
                ),
                Divider(color: context.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                _RailExpandButton(
                  isExpanded: _isExpanded,
                  onPressed: () {
                    setState(() => _isExpanded = !_isExpanded);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: LayoutBuilder(
                builder: (_, constraints) {
                  _updateSideBarWidth(constraints.maxWidth);
                  return widget.child;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppCommandBrand extends StatelessWidget {
  final bool showLabel;

  const _AppCommandBrand({required this.showLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          const SizedBox(width: 44, height: 44, child: AppIcon()),
          if (showLabel) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'FlClash',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.25,
                    ),
                  ),
                  Text(
                    'Proxy Control',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.secondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppRailItem extends StatefulWidget {
  final NavigationItem item;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onPressed;

  const _AppRailItem({
    required this.item,
    required this.isSelected,
    required this.showLabel,
    required this.onPressed,
  });

  @override
  State<_AppRailItem> createState() => _AppRailItemState();
}

class _AppRailItemState extends State<_AppRailItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foregroundColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final content = SizedBox(
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onPressed,
          onHover: (value) {
            if (_isHovered != value) {
              setState(() {
                _isHovered = value;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primary.withAlpha(
                      Theme.brightnessOf(context) == Brightness.dark ? 48 : 25,
                    )
                  : _isHovered
                  ? colorScheme.surfaceContainerHigh.withAlpha(160)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isSelected
                    ? colorScheme.primary.withAlpha(72)
                    : Colors.transparent,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.showLabel ? 12 : 0,
              ),
              child: Row(
                mainAxisAlignment: widget.showLabel
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    child: IconTheme(
                      data: IconThemeData(
                        color: widget.isSelected
                            ? colorScheme.primary
                            : foregroundColor,
                        size: 22,
                      ),
                      child: widget.item.icon,
                    ),
                  ),
                  if (widget.showLabel) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        navigationLabel(widget.item.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelLarge?.copyWith(
                          color: widget.isSelected
                              ? colorScheme.onPrimaryContainer
                              : foregroundColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.showLabel) {
      return content;
    }
    return Tooltip(message: navigationLabel(widget.item.label), child: content);
  }
}

class _RailExpandButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const _RailExpandButton({required this.isExpanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final label = context.appLocalizations.more;
    return Tooltip(
      message: label,
      child: SizedBox(
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 0),
              child: Row(
                mainAxisAlignment: isExpanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
