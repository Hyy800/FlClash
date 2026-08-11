import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/window_manager.dart';
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
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return Row(
      children: [
        AnimatedContainer(
          duration: midDuration,
          curve: Curves.easeOutCubic,
          width: showLabel ? 236 : 88,
          margin: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.colorScheme.outlineVariant.withAlpha(120),
            ),
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colorScheme.surfaceContainerHigh.withAlpha(225),
                context.colorScheme.surfaceContainerLow.withAlpha(210),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: context.colorScheme.shadow.withAlpha(60),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (system.isMacOS) const SizedBox(height: 18),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: showLabel ? 4 : 2,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: showLabel
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      if (!system.isMacOS) const AppIcon(),
                      if (showLabel && !system.isMacOS) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appName,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: context.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: HiddenBarScrollBehavior(),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: navigationItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = navigationItems[index];
                        return _AppSidebarItem(
                          item: item,
                          isSelected: currentIndex == index,
                          showLabel: showLabel,
                          onPressed: () {
                            _handleToPage(item.label);
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: context.colorScheme.outlineVariant),
                const SizedBox(height: 8),
                Align(
                  alignment: showLabel
                      ? Alignment.centerRight
                      : Alignment.center,
                  child: IconButton(
                    tooltip: showLabel ? null : appName,
                    onPressed: () {
                      ref
                          .read(appSettingProvider.notifier)
                          .update(
                            (state) =>
                                state.copyWith(showLabel: !state.showLabel),
                          );
                    },
                    icon: Icon(
                      showLabel
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
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

class _AppSidebarItem extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onPressed;

  const _AppSidebarItem({
    required this.item,
    required this.isSelected,
    required this.showLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: AnimatedContainer(
            duration: midDuration,
            curve: Curves.easeOutCubic,
            height: 54,
            padding: EdgeInsets.symmetric(horizontal: showLabel ? 14 : 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withAlpha(70)
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(18),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer.withAlpha(210),
                      ],
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 22),
                  child: item.icon,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      Intl.message(item.label.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    );
    if (showLabel) {
      return content;
    }
    return Tooltip(message: Intl.message(item.label.name), child: content);
  }
}
