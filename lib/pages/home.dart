import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context) {
    return HomeBackScopeContainer(
      child: AppBackdrop(
        child: AppSidebarContainer(
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(navigationStateProvider);
              final isMobile = state.viewMode == ViewMode.mobile;
              final navigationItems = state.navigationItems;
              final currentIndex = state.currentIndex;
              final bottomNavigationBar = _AppBottomDock(
                items: navigationItems,
                currentIndex: currentIndex,
                onSelected: (index) {
                  _handleToPage(navigationItems[index].label);
                },
              );
              if (isMobile) {
                return Column(
                  children: [
                    Expanded(
                      child: MediaQuery.removePadding(
                        removeTop: false,
                        removeBottom: true,
                        removeLeft: true,
                        removeRight: true,
                        context: context,
                        child: child!,
                      ),
                    ),
                    MediaQuery.removePadding(
                      removeTop: true,
                      removeBottom: false,
                      removeLeft: true,
                      removeRight: true,
                      context: context,
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: bottomNavigationBar,
                      ),
                    ),
                  ],
                );
              } else {
                return child!;
              }
            },
            child: Consumer(
              builder: (_, ref, _) {
                final navigationItems = ref
                    .watch(currentNavigationItemsStateProvider)
                    .value;
                final isMobile = ref.watch(isMobileViewProvider);
                return _HomePageView(
                  navigationItems: navigationItems,
                  pageBuilder: (_, index) {
                    final navigationItem = navigationItems[index];
                    final navigationView = navigationItem.builder(context);
                    final view = KeepScope(
                      keep: navigationItem.keep,
                      child: isMobile
                          ? navigationView
                          : Navigator(
                              pages: [MaterialPage(child: navigationView)],
                              onDidRemovePage: (_) {},
                            ),
                    );
                    return view;
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    final pageLabel = ref.read(currentPageLabelProvider);
    return widget.navigationItems.indexWhere((item) => item.label == pageLabel);
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    if (isAnimateToPage && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      currentNavigationItemsStateProvider.select((state) => state.value.length),
    );
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class _AppBottomDock extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final OnSelected onSelected;

  const _AppBottomDock({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _AppBottomDockItem(
                  item: items[index],
                  isSelected: currentIndex == index,
                  onPressed: () {
                    onSelected(index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppBottomDockItem extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onPressed;

  const _AppBottomDockItem({
    required this.item,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onPressed,
            child: AnimatedContainer(
              duration: midDuration,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isSelected
                    ? colorScheme.primary.withAlpha(24)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary.withAlpha(90)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: 22,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    child: item.icon,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    Intl.message(item.label.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  final Widget child;

  const HomeBackScopeContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context, ref) {
    return CommonPopScope(
      onPop: (context) async {
        final pageLabel = ref.read(currentPageLabelProvider);
        final realContext =
            GlobalObjectKey(pageLabel).currentContext ?? context;
        final canPop = Navigator.canPop(realContext);
        if (canPop) {
          Navigator.of(realContext).pop();
        } else {
          await globalState.container
              .read(systemActionProvider.notifier)
              .handleClose();
        }
        return false;
      },
      child: child,
    );
  }
}
