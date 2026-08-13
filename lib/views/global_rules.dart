import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/overwrite/rule.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      if (mounted) {
        context.showNotifier(error.toString());
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOrEdit([Rule? rule]) async {
    final result = await globalState.showCommonDialog<Rule>(
      child: AddOrEditRuleDialog(rule: rule),
    );
    if (result == null || !mounted) return;
    final rules = [...ref.read(globalRulesProvider)];
    final index = rules.indexWhere((item) => item.id == result.id);
    if (index < 0) {
      rules.add(result);
    } else {
      rules[index] = result;
    }
    await _commit(rules);
  }

  Future<void> _delete(Rule rule) async {
    final rules = ref
        .read(globalRulesProvider)
        .where((item) => item.id != rule.id)
        .toList();
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
    return CommonScaffold(
      title: context.appLocalizations.globalRules,
      isLoading: _saving,
      actions: [
        FilledButton.tonalIcon(
          onPressed: _saving ? null : _addOrEdit,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.appLocalizations.add),
        ),
      ],
      body: rules.isEmpty
          ? NullStatus(label: context.appLocalizations.noData)
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              buildDefaultDragHandles: false,
              itemCount: rules.length,
              onReorderItem: _saving ? (_, _) {} : _reorder,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return Card(
                  key: ValueKey(rule.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator_rounded),
                    ),
                    title: Text(
                      rule.rawValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.toJetBrainsMono,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.appLocalizations.edit,
                          onPressed: _saving ? null : () => _addOrEdit(rule),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: context.appLocalizations.delete,
                          onPressed: _saving ? null : () => _delete(rule),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    onTap: _saving ? null : () => _addOrEdit(rule),
                  ),
                );
              },
            ),
    );
  }
}
