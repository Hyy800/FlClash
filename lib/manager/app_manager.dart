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
import 'package:intl/intl.dart';

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

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final groupWidth = constraints.maxWidth > 1408
              ? 1408.0
              : constraints.maxWidth;
          final panelHeight = constraints.maxHeight > 900
              ? 900.0
              : constraints.maxHeight;
          final availableRailHeight = panelHeight - 28;
          final railHeight = availableRailHeight
              .clamp(300.0, 620.0)
              .toDouble();
          const contentLeft = 48.0;
          return Center(
            child: SizedBox(
              width: groupWidth,
              height: panelHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    left: contentLeft,
                    child: AppGlassPanel(
                      borderRadius: BorderRadius.circular(34),
                      child: LayoutBuilder(
                        builder: (_, contentConstraints) {
                          _updateSideBarWidth(ref, contentConstraints.maxWidth);
                          return child;
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: (panelHeight - railHeight) / 2,
                    child: SizedBox(
                      width: 72,
                      height: railHeight,
                      child: AppGlassPanel(
                        borderRadius: BorderRadius.circular(36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            if (system.isMacOS) const SizedBox(height: 8),
                            if (!system.isMacOS)
                              Container(
                                width: 46,
                                height: 46,
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: context.colorScheme.primary.withAlpha(
                                    30,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const AppIcon(),
                              ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: HiddenBarScrollBehavior(),
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: navigationItems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = navigationItems[index];
                                    return _AppRailItem(
                                      item: item,
                                      isSelected: currentIndex == index,
                                      onPressed: () {
                                        _handleToPage(item.label);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppRailItem extends StatefulWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _AppRailItem({
    required this.item,
    required this.isSelected,
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
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onPressed,
          onHover: (value) {
            if (_isHovered != value) {
              setState(() {
                _isHovered = value;
              });
            }
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            scale: _isHovered && !widget.isSelected ? 1.06 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? colorScheme.primary
                    : _isHovered
                    ? colorScheme.surfaceContainerHighest.withAlpha(180)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(74),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : const [],
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: widget.isSelected
                      ? colorScheme.onPrimary
                      : foregroundColor,
                  size: 22,
                ),
                child: widget.item.icon,
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(
      message: Intl.message(widget.item.label.name),
      child: content,
    );
  }
}
