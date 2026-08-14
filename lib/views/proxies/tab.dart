import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

typedef ProxyGroupViewKeyMap =
    Map<String, GlobalObjectKey<_ProxyGroupViewState>>;

class ProxyNodePanel extends StatelessWidget {
  final Widget child;

  const ProxyNodePanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('proxy-node-panel'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: child,
    );
  }
}

class ProxyTabMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const ProxyTabMoreButton({
    super.key,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('proxy-group-more-button'),
      style: IconButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class ProxyTabHeaderBoundary extends StatelessWidget {
  final bool hasOverflow;
  final Widget tabs;
  final Widget moreButton;

  const ProxyTabHeaderBoundary({
    super.key,
    required this.hasOverflow,
    required this.tabs,
    required this.moreButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRect(
            key: const ValueKey('proxy-group-tabs-clip'),
            child: Padding(
              padding: EdgeInsets.only(right: hasOverflow ? 8 : 0),
              child: tabs,
            ),
          ),
        ),
        if (hasOverflow)
          SizedBox(
            key: const ValueKey('proxy-group-more-slot'),
            width: 50,
            height: 46,
            child: moreButton,
          ),
      ],
    );
  }
}

class ProxiesTabView extends ConsumerStatefulWidget {
  const ProxiesTabView({super.key});

  static Map<String, PageStorageKey> pageListStoreMap = {};

  @override
  ConsumerState<ProxiesTabView> createState() => ProxiesTabViewState();
}

class ProxiesTabViewState extends ConsumerState<ProxiesTabView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _hasMoreButtonNotifier = ValueNotifier<bool>(false);
  ProxyGroupViewKeyMap _keyMap = {};

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxiesTabControllerStateProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      if (!stringListEquality.equals(prev?.a, next.a)) {
        _destroyTabController();
        final groupNames = next.a;
        final currentGroupName = next.b;
        final index = groupNames.indexWhere((item) => item == currentGroupName);
        _updateTabController(groupNames.length, index);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _destroyTabController();
    super.dispose();
  }

  void scrollToGroupSelected() {
    final group = currentGroup;
    if (group == null) {
      return;
    }
    _keyMap[group.name]?.currentState?.scrollToSelected();
  }

  Future<void> delayTestCurrentGroup() async {
    final group = currentGroup;
    if (group == null) {
      return;
    }
    await delayTest(group.all, group.testUrl);
  }

  Group? get currentGroup {
    return _getGroup(_tabController?.index);
  }

  Group? _getGroup(int? index) {
    final groups = ref.read(proxiesTabStateProvider).groups;
    if (index == null || index < 0 || index >= groups.length) {
      return null;
    }
    return groups[index];
  }

  Widget _buildMoreButton() {
    return Consumer(
      builder: (_, ref, _) {
        final isMobileView = ref.watch(isMobileViewProvider);
        return ProxyTabMoreButton(
          onPressed: _showMoreMenu,
          icon: isMobileView
              ? Icons.expand_more_rounded
              : Icons.chevron_right_rounded,
        );
      },
    );
  }

  void _showMoreMenu() {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: false),
      builder: (_) {
        return AdaptiveSheetScaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (_, ref, _) {
                final state = ref.watch(proxiesTabControllerStateProvider);
                final groupNames = state.a;
                final currentGroupName = state.b;
                return SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      for (final groupName in groupNames)
                        SettingTextCard(
                          groupName,
                          onPressed: () {
                            final index = groupNames.indexWhere(
                              (item) => item == groupName,
                            );
                            if (index == -1) return;
                            _tabController?.animateTo(index);
                            updateCurrentGroupName(groupName);
                            Navigator.of(context).pop();
                          },
                          isSelected: groupName == currentGroupName,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          title: context.appLocalizations.proxyGroup,
        );
      },
    );
  }

  void _tabControllerListener([int? index]) {
    final group = _getGroup(index ?? _tabController?.index);
    if (group == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      updateCurrentGroupName(group.name);
    });
  }

  void _destroyTabController() {
    _tabController?.removeListener(_tabControllerListener);
    _tabController?.dispose();
    _tabController = null;
  }

  void _updateTabController(int length, int index) {
    _destroyTabController();
    if (length == 0) {
      return;
    }
    final realIndex = index == -1 ? 0 : index;
    _tabController ??= TabController(
      length: length,
      initialIndex: realIndex,
      vsync: this,
    );
    _tabControllerListener(realIndex);
    _tabController?.addListener(_tabControllerListener);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    ref.watch(themeSettingProvider.select((state) => state.textScale));
    final state = ref.watch(proxiesTabStateProvider.select((state) => state));
    final proxiesLayout = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.layout),
    );
    final groups = state.groups;
    if (groups.isEmpty || _tabController == null) {
      return NullStatus(
        illustration: const ProxyEmptyIllustration(),
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }
    _keyMap = {};
    return ProxyNodePanel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (scrollNotification) {
              _hasMoreButtonNotifier.value =
                  scrollNotification.metrics.maxScrollExtent > 0;
              return false;
            },
            child: ValueListenableBuilder(
              valueListenable: _hasMoreButtonNotifier,
              builder: (_, value, child) {
                return ProxyTabHeaderBoundary(
                  hasOverflow: value,
                  moreButton: child!,
                  tabs: TabBar(
                    controller: _tabController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    dividerColor: Colors.transparent,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (final group in groups)
                        Tab(
                          height: 46,
                          child: Builder(
                            builder: (context) {
                              return EmojiText(
                                group.name,
                                style: DefaultTextStyle.of(context).style,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
              child: _buildMoreButton(),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final columns = utils.getProxiesColumns(
                  max(constraints.maxWidth - 32, 0),
                  proxiesLayout,
                );
                return TabBarView(
                  controller: _tabController,
                  children: [
                    for (final group in groups)
                      ProxyGroupView(
                        key: _keyMap.updateCacheValue(
                          group.name,
                          () =>
                              GlobalObjectKey<_ProxyGroupViewState>(group.name),
                        ),
                        group: group,
                        columns: columns,
                        cardType: state.proxyCardType,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProxyGroupView extends ConsumerStatefulWidget {
  final Group group;
  final int columns;
  final ProxyCardType cardType;

  const ProxyGroupView({
    super.key,
    required this.group,
    required this.columns,
    required this.cardType,
  });

  @override
  ConsumerState<ProxyGroupView> createState() => _ProxyGroupViewState();
}

class _ProxyGroupViewState extends ConsumerState<ProxyGroupView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  PageStorageKey _getPageStorageKey() {
    final profile = globalState.container.read(currentProfileProvider);
    final key =
        '${profile?.id}_${ScrollPositionCacheKey.proxiesTabList.name}_${widget.group.name}';
    return ProxiesTabView.pageListStoreMap.updateCacheValue(
      key,
      () => PageStorageKey(key),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void scrollToSelected() {
    if (_controller.position.maxScrollExtent == 0) {
      return;
    }
    _controller.animateTo(
      min(
        16 +
            getScrollToSelectedOffset(
              groupName: widget.group.name,
              proxies: widget.group.all,
              columns: widget.columns,
            ),
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final proxies = group.all;
    return CommonScrollBar(
      controller: _controller,
      child: GridView.builder(
        key: _getPageStorageKey(),
        controller: _controller,
        padding: const EdgeInsets.only(
          top: 12,
          left: 12,
          right: 12,
          bottom: 96,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: getItemHeight(widget.cardType),
        ),
        itemCount: proxies.length,
        itemBuilder: (_, index) {
          final proxy = proxies[index];
          return ProxyCard(
            testUrl: group.testUrl,
            groupType: group.type,
            type: widget.cardType,
            proxy: proxy,
            groupName: group.name,
          );
        },
      ),
    );
  }
}

class DelayTestButton extends StatefulWidget {
  final Future Function() onClick;

  const DelayTestButton({super.key, required this.onClick});

  @override
  State<DelayTestButton> createState() => _DelayTestButtonState();
}

class _DelayTestButtonState extends State<DelayTestButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Future<void> _healthcheck() async {
    if (_controller.isAnimating) {
      return;
    }
    _controller.forward();
    try {
      await widget.onClick();
    } finally {
      if (mounted) {
        _controller.reverse();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return AnimatedBuilder(
      animation: _controller.view,
      builder: (_, child) {
        return FadeTransition(
          opacity: _animation,
          child: ScaleTransition(scale: _animation, child: child),
        );
      },
      child: CommonFloatingActionButton(
        onPressed: _healthcheck,
        label: appLocalizations.delayTest,
        icon: const Icon(Icons.network_ping),
      ),
    );
  }
}
