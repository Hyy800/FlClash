import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
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
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  // Widget _buildLoading() {
  //   return Consumer(
  //     builder: (_, ref, _) {
  //       final loading = ref.watch(loadingProvider);
  //       final isMobileView = ref.watch(isMobileViewProvider);
  //       return loading && !isMobileView
  //           ? RotatedBox(
  //               quarterTurns: 1,
  //               child: const LinearProgressIndicator(),
  //             )
  //           : Container();
  //     },
  //   );
  // }

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
    return Row(
      children: [
        Container(
          width: 72,
          margin: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLow,
            border: Border.all(
              color: context.colorScheme.outlineVariant.withAlpha(90),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (system.isMacOS) const SizedBox(height: 18),
                if (!system.isMacOS) const AppIcon(),
                const SizedBox(height: 18),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: HiddenBarScrollBehavior(),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: navigationItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
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
        Expanded(
          child: ClipRect(
            child: LayoutBuilder(
              builder: (_, constraints) {
                _updateSideBarWidth(ref, constraints.maxWidth);
                return child;
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AppRailItem extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _AppRailItem({
    required this.item,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final content = SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: midDuration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withAlpha(24)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 3,
                      height: 26,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 22),
                  child: item.icon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: Intl.message(item.label.name), child: content);
  }
}
