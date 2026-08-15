import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/overwrite/rule.dart';
import 'package:fl_clash/features/overwrite/rule_target.dart';
import 'package:fl_clash/features/overwrite/rule_usage.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

class GlobalRulesView extends ConsumerStatefulWidget {
  const GlobalRulesView({super.key});

  @override
  ConsumerState<GlobalRulesView> createState() => _GlobalRulesViewState();
}

class _GlobalRulesViewState extends ConsumerState<GlobalRulesView> {
  bool _saving = false;

  Future<bool> _commit(List<Rule> rules) async {
    if (_saving) return false;
    final previous = ref.read(globalRulesProvider);
    setState(() => _saving = true);
    ref.read(globalRulesProvider.notifier).value = List.unmodifiable(rules);
    try {
      await ref
          .read(setupActionProvider.notifier)
          .applyProfile(force: true, silence: true);
      await preferences.saveConfig(ref.read(configProvider));
      return true;
    } catch (error) {
      ref.read(globalRulesProvider.notifier).value = previous;
      if (mounted) context.showNotifier(error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOrEdit([
    Rule? rule,
    RuleAction? initialAction,
    String? initialContent,
  ]) async {
    final result = await globalState.showCommonDialog<Rule>(
      child: AddOrEditRuleDialog(
        rule: rule,
        initialAction: initialAction,
        initialContent: initialContent,
      ),
    );
    if (result == null || !mounted) return;
    final rules = [...ref.read(globalRulesProvider)];
    final index = rules.indexWhere((item) => item.id == result.id);
    if (index < 0) {
      if (result.ruleAction == RuleAction.PROCESS_PATH ||
          result.ruleAction == RuleAction.PROCESS_NAME) {
        rules.insert(0, result);
      } else {
        rules.add(result);
      }
    } else {
      rules[index] = result;
    }
    await _commit(rules);
  }

  Future<void> _addApplicationRule() async {
    final file = await FilePicker.pickFile(
      dialogTitle: context.appLocalizations.application,
      type: FileType.custom,
      allowedExtensions: const ['exe'],
      lockParentWindow: true,
    );
    final path = file?.path;
    if (path == null || !mounted) return;
    await _addOrEdit(null, RuleAction.PROCESS_PATH, path);
  }

  Future<void> _delete(Rule rule) async {
    final rules = ref
        .read(globalRulesProvider)
        .where((item) => item.id != rule.id)
        .toList();
    await _commit(rules);
  }

  Future<void> _setEnabled(Rule rule, bool enabled) async {
    final rules = [
      for (final item in ref.read(globalRulesProvider))
        item.id == rule.id ? item.copyWith(enabled: enabled) : item,
    ];
    await _commit(rules);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final rules = [...ref.read(globalRulesProvider)];
    final rule = rules.removeAt(oldIndex);
    rules.insert(newIndex, rule);
    await _commit(rules);
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(globalRulesProvider);
    final ruleUsage = ref.watch(ruleUsagesProvider);
    final groups = ref.watch(groupsProvider);
    final availableTargets = buildRuleTargetOptions(
      groups,
      activeProfile: ref.watch(currentProfileProvider)?.realLabel,
    ).map((option) => option.name).toSet();
    final targetsReady = groups.isNotEmpty;
    final activeCount = rules.where((rule) {
      final target = rule.ruleTarget;
      return rule.enabled &&
          target != null &&
          (!targetsReady || availableTargets.contains(target));
    }).length;
    return CommonScaffold(
      title: context.appLocalizations.globalRules,
      isLoading: _saving,
      actions: [
        FilledButton.tonalIcon(
          onPressed: _saving ? null : _addApplicationRule,
          style: FilledButton.styleFrom(side: BorderSide.none),
          icon: const Icon(Icons.apps_rounded),
          label: Text(context.appLocalizations.application),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _addOrEdit,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.appLocalizations.addRule),
        ),
      ],
      body: Column(
        children: [
          _RulesOverview(
            total: rules.length,
            active: activeCount,
            nodeCount: availableTargets.length,
          ),
          Expanded(
            child: rules.isEmpty
                ? _EmptyRules(onAdd: _saving ? null : _addOrEdit)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    buildDefaultDragHandles: false,
                    itemCount: rules.length,
                    onReorderItem: _saving ? (_, _) {} : _reorder,
                    proxyDecorator: (child, _, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) => Material(
                        elevation: 8 * animation.value,
                        borderRadius: BorderRadius.circular(18),
                        child: child,
                      ),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      final available =
                          availableTargets.contains(rule.ruleTarget) ||
                          !targetsReady;
                      return _RuleRouteCard(
                        key: ValueKey(rule.id),
                        index: index,
                        rule: rule,
                        usage: ruleUsage[rule.id] ?? const RuleUsage(),
                        available: available,
                        saving: _saving,
                        onEnabledChanged: (enabled) =>
                            _setEnabled(rule, enabled),
                        onEdit: () => _addOrEdit(rule),
                        onDelete: () => _delete(rule),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RulesOverview extends StatelessWidget {
  final int total;
  final int active;
  final int nodeCount;

  const _RulesOverview({
    required this.total,
    required this.active,
    required this.nodeCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.opacity60),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.alt_route_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.appLocalizations.globalRulesDesc,
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$active / $total · $nodeCount ${context.appLocalizations.ruleTarget}',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRules extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyRules({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.route_outlined,
                size: 56,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                context.appLocalizations.noData,
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.appLocalizations.globalRulesDesc,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.appLocalizations.addRule),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRouteCard extends StatelessWidget {
  final int index;
  final Rule rule;
  final RuleUsage usage;
  final bool available;
  final bool saving;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleRouteCard({
    super.key,
    required this.index,
    required this.rule,
    required this.usage,
    required this.available,
    required this.saving,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final targetColor = !rule.enabled
        ? colorScheme.onSurfaceVariant
        : available
        ? colorScheme.primary
        : colorScheme.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: rule.enabled
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLow.withValues(alpha: 0.62),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: !rule.enabled
              ? colorScheme.outlineVariant.opacity60
              : available
              ? colorScheme.outlineVariant.opacity60
              : colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: saving ? null : onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
          child: Column(
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    enabled: !saving,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Row(
                      children: [
                        _RouteSegment(
                          eyebrow: context.appLocalizations.ruleName,
                          value: rule.ruleAction.value,
                          icon: Icons.filter_alt_outlined,
                        ),
                        _RouteRail(color: colorScheme.outlineVariant),
                        Expanded(
                          flex: 2,
                          child: _RouteSegment(
                            eyebrow: context.appLocalizations.content,
                            value: rule.realContent ?? '',
                            icon: Icons.travel_explore_rounded,
                          ),
                        ),
                        _RouteRail(color: targetColor),
                        Expanded(
                          flex: 2,
                          child: _RouteSegment(
                            eyebrow: available
                                ? context.appLocalizations.ruleTarget
                                : context
                                      .appLocalizations
                                      .ruleTargetUnavailable,
                            value: rule.realTarget ?? '',
                            icon: available
                                ? Icons.dns_outlined
                                : Icons.warning_amber_rounded,
                            color: targetColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: rule.enabled,
                    onChanged: saving ? null : onEnabledChanged,
                  ),
                  Material(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(11),
                    clipBehavior: Clip.antiAlias,
                    child: PopupMenuButton<_RuleAction>(
                      enabled: !saving,
                      color: colorScheme.surfaceContainerHigh,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.black.withValues(alpha: 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide.none,
                      ),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).showMenuTooltip,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        side: BorderSide.none,
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case _RuleAction.edit:
                            onEdit();
                          case _RuleAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _RuleAction.edit,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(context.appLocalizations.edit),
                          ),
                        ),
                        PopupMenuItem(
                          value: _RuleAction.delete,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: colorScheme.error,
                            ),
                            title: Text(
                              context.appLocalizations.delete,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _RuleUsageStrip(usage: usage),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleUsageStrip extends StatelessWidget {
  final RuleUsage usage;

  const _RuleUsageStrip({required this.usage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final networks = usage.networks.toList()..sort();
    final networkText = networks.isEmpty ? '--' : networks.join(' / ');
    final speed = usage.currentSpeed.traffic.show;
    final sessionTraffic = usage.sessionTraffic.traffic.show;
    final cumulativeTraffic = usage.totalTraffic.traffic.show;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          _UsageItem(
            icon: Icons.lan_outlined,
            label: context.appLocalizations.network,
            value: networkText,
          ),
          _UsageItem(
            icon: Icons.speed_rounded,
            label: context.appLocalizations.networkSpeed,
            value: usage.requestCount == 0 ? '--' : '$speed/s',
          ),
          _UsageItem(
            icon: Icons.data_usage_rounded,
            label: context.appLocalizations.sessionTraffic,
            value: sessionTraffic,
          ),
          _UsageItem(
            icon: Icons.all_inclusive_rounded,
            label: context.appLocalizations.cumulativeTraffic,
            value: cumulativeTraffic,
          ),
        ],
      ),
    );
  }
}

class _UsageItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _UsageItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          '$label  ',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: context.textTheme.labelMedium?.toJetBrainsMono.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _RuleAction { edit, delete }

class _RouteSegment extends StatelessWidget {
  final String eyebrow;
  final String value;
  final IconData icon;
  final Color? color;

  const _RouteSegment({
    required this.eyebrow,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 19, color: effectiveColor),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: effectiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.toJetBrainsMono.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteRail extends StatelessWidget {
  final Color color;

  const _RouteRail({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(width: 18, height: 1, color: color),
          Icon(Icons.chevron_right_rounded, size: 18, color: color),
        ],
      ),
    );
  }
}
