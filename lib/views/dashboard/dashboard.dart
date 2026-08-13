import 'package:defer_pointer/defer_pointer.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/start_button.dart';

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  void dispose() {
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  Future<void> _handleConnection() async {
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? context.appLocalizations.forceRestartCoreTip
        : context.appLocalizations.restartCoreTip;
    final res = await globalState.showMessage(message: TextSpan(text: tip));
    if (res != true) {
      return;
    }
    globalState.container.read(coreActionProvider.notifier).restartCore();
  }

  List<Widget> _buildActions(bool isEdit) {
    final appLocalizations = context.appLocalizations;
    return [
      if (!isEdit)
        Consumer(
          builder: (_, ref, _) {
            final coreStatus = ref.watch(coreStatusProvider);
            return Tooltip(
              message: appLocalizations.coreStatus,
              child: FadeScaleBox(
                alignment: Alignment.centerRight,
                child: coreStatus == CoreStatus.connected
                    ? IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF16866F),
                          foregroundColor: switch (Theme.brightnessOf(
                            context,
                          )) {
                            Brightness.light =>
                              context.colorScheme.onSurfaceVariant,
                            Brightness.dark =>
                              context.colorScheme.onPrimaryFixedVariant,
                          },
                        ),
                        onPressed: _handleConnection,
                        icon: const Icon(
                          Icons.check,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : FilledButton.icon(
                        key: ValueKey(coreStatus),
                        onPressed: _handleConnection,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => Colors.greenAccent,
                            CoreStatus.disconnected =>
                              context.colorScheme.error,
                          },
                          foregroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => switch (Theme.brightnessOf(
                              context,
                            )) {
                              Brightness.light =>
                                context.colorScheme.onSurfaceVariant,
                              Brightness.dark => null,
                            },
                            CoreStatus.disconnected =>
                              context.colorScheme.onError,
                          },
                        ),
                        icon: SizedBox(
                          height: globalState.measure.bodyMediumHeight,
                          width: globalState.measure.bodyMediumHeight,
                          child: switch (coreStatus) {
                            CoreStatus.connecting => Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: context.colorScheme.onPrimary,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            CoreStatus.connected => const Icon(
                              Icons.check_sharp,
                              fontWeight: FontWeight.w900,
                            ),
                            CoreStatus.disconnected => const Icon(
                              Icons.restart_alt_sharp,
                              fontWeight: FontWeight.w900,
                            ),
                          },
                        ),
                        label: Text(switch (coreStatus) {
                          CoreStatus.connecting => appLocalizations.connecting,
                          CoreStatus.connected => appLocalizations.connected,
                          CoreStatus.disconnected =>
                            appLocalizations.disconnected,
                        }),
                      ),
              ),
            );
          },
        ),
      if (isEdit)
        ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, addedChildren, child) {
            if (addedChildren.isEmpty) {
              return Container();
            }
            return child!;
          },
          child: IconButton(
            onPressed: () {
              _showAddWidgetsModal();
            },
            icon: const Icon(Icons.add_circle),
          ),
        ),
      FadeRotationScaleBox(
        child: isEdit
            ? IconButton(
                key: const ValueKey(true),
                icon: const Icon(Icons.save, key: ValueKey('save-icon')),
                onPressed: _handleUpdateIsEdit,
              )
            : IconButton(
                key: const ValueKey(false),
                icon: const Icon(Icons.edit, key: ValueKey('edit-icon')),
                onPressed: _handleUpdateIsEdit,
              ),
      ),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: context.appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  Future<void> _handleUpdateIsEdit() async {
    if (_isEditNotifier.value == true) {
      await _handleSave();
    }
    _isEditNotifier.value = !_isEditNotifier.value;
  }

  Future<void> _handleSave() async {
    final currentState = key.currentState;
    if (currentState == null) {
      return;
    }
    if (mounted && currentState.children.isNotEmpty) {
      await currentState.isTransformCompleter;
      final dashboardWidgets = currentState.children
          .map((item) => DashboardWidget.getDashboardWidget(item))
          .toList();
      ref
          .read(appSettingProvider.notifier)
          .update(
            (state) => state.copyWith(dashboardWidgets: dashboardWidgets),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    const columns = 12;
    final spacing = 8.mAp;
    final children = [
      ...dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) =>
                !children.contains(item.widget) &&
                item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget)
          .toList();
    });
    return _buildIsEdit(
      (isEdit) => CommonScaffold(
        title: context.appLocalizations.dashboard,
        actions: _buildActions(isEdit),
        floatingActionButton: const StartButton(),
        body: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 0.9),
            iconTheme: Theme.of(context).iconTheme.copyWith(size: 19),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(12.mAp, 6.mAp, 12.mAp, 64.mAp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DashboardCommandHeader(),
                  const SizedBox(height: 8),
                  if (isEdit)
                    SystemBackBlock(
                      child: CommonPopScope(
                        onPop: (context) {
                          _handleUpdateIsEdit();
                          return false;
                        },
                        child: SuperGrid(
                          key: key,
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          onUpdate: _handleSave,
                          children: children,
                        ),
                      ),
                    )
                  else
                    Grid(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      children: children,
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

class _DashboardCommandHeader extends ConsumerWidget {
  const _DashboardCommandHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreStatus = ref.watch(coreStatusProvider);
    final isStart = ref.watch(isStartProvider);
    final runTime = ref.watch(runTimeProvider);
    final colorScheme = context.colorScheme;
    final statusColor = switch (coreStatus) {
      CoreStatus.connected => colorScheme.secondary,
      CoreStatus.connecting => colorScheme.tertiary,
      CoreStatus.disconnected => colorScheme.error,
    };
    final statusLabel = switch (coreStatus) {
      CoreStatus.connected => context.appLocalizations.connected,
      CoreStatus.connecting => context.appLocalizations.connecting,
      CoreStatus.disconnected => context.appLocalizations.disconnected,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${context.appLocalizations.coreStatus} · $statusLabel',
                style: context.textTheme.labelLarge,
              ),
            ],
          );
          final runtime = Text(
            isStart
                ? utils.getTimeText(runTime)
                : context.appLocalizations.stop,
            style: context.textTheme.titleMedium?.copyWith(
              color: isStart
                  ? colorScheme.secondary
                  : colorScheme.onSurfaceVariant,
              fontFamily: FontFamily.jetBrainsMono.value,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [status, const SizedBox(height: 8), runtime],
            );
          }
          return Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 20),
              const SizedBox(width: 10),
              status,
              const Spacer(),
              Text(
                'UPTIME',
                style: context.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              runtime,
            ],
          );
        },
      ),
    );
  }
}

class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 12,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: const EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
