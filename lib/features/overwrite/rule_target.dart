import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RuleTargetKind { builtIn, group, proxy }

enum RuleTargetSort { original, delay, name }

class RuleTargetOption {
  final String name;
  final RuleTargetKind kind;
  final int order;
  final String? profile;

  const RuleTargetOption({
    required this.name,
    required this.kind,
    required this.order,
    this.profile,
  });
}

String? _profileFromTarget(String name) {
  final match = RegExp(r'^\[([^\]]+)\]\s+').firstMatch(name);
  return match?.group(1)?.trim();
}

List<RuleTargetOption> buildRuleTargetOptions(
  List<Group> groups, {
  String? activeProfile,
}) {
  final options = <RuleTargetOption>[];
  final names = <String>{};

  void add(String name, RuleTargetKind kind) {
    if (name.isEmpty || name.toUpperCase() == 'MATCH' || !names.add(name)) {
      return;
    }
    options.add(
      RuleTargetOption(
        name: name,
        kind: kind,
        order: options.length,
        profile: kind == RuleTargetKind.builtIn
            ? null
            : _profileFromTarget(name) ?? activeProfile,
      ),
    );
  }

  for (final target in RuleTarget.values) {
    add(target.name, RuleTargetKind.builtIn);
  }
  for (final group in groups) {
    add(group.name, RuleTargetKind.group);
  }
  for (final group in groups) {
    for (final proxy in group.all) {
      add(proxy.name, RuleTargetKind.proxy);
    }
  }
  return options;
}

List<RuleTargetOption> filterAndSortRuleTargets({
  required List<RuleTargetOption> options,
  required String query,
  required RuleTargetSort sort,
  RuleTargetKind? kind,
  String? profile,
  int? Function(String name)? delayOf,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final result = options.where((option) {
    final matchesKind = kind == null || option.kind == kind;
    final matchesProfile = profile == null || option.profile == profile;
    final matchesQuery =
        normalizedQuery.isEmpty ||
        option.name.toLowerCase().contains(normalizedQuery);
    return matchesKind && matchesProfile && matchesQuery;
  }).toList();
  switch (sort) {
    case RuleTargetSort.original:
      result.sort((a, b) => a.order.compareTo(b.order));
    case RuleTargetSort.delay:
      result.sort((a, b) {
        final aDelay = delayOf?.call(a.name);
        final bDelay = delayOf?.call(b.name);
        final aValue = aDelay != null && aDelay > 0 ? aDelay : 1 << 30;
        final bValue = bDelay != null && bDelay > 0 ? bDelay : 1 << 30;
        final delayCompare = aValue.compareTo(bValue);
        return delayCompare != 0 ? delayCompare : a.order.compareTo(b.order);
      });
    case RuleTargetSort.name:
      result.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  }
  return result;
}

class RuleTargetSelectorDialog extends ConsumerStatefulWidget {
  final String value;

  const RuleTargetSelectorDialog({super.key, required this.value});

  @override
  ConsumerState<RuleTargetSelectorDialog> createState() =>
      _RuleTargetSelectorDialogState();
}

class _RuleTargetSelectorDialogState
    extends ConsumerState<RuleTargetSelectorDialog> {
  final _searchController = TextEditingController();
  RuleTargetSort _sort = RuleTargetSort.original;
  RuleTargetKind? _kind;
  String? _profile;
  bool _testing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _sortLabel(BuildContext context, RuleTargetSort sort) {
    final localizations = context.appLocalizations;
    return switch (sort) {
      RuleTargetSort.original => localizations.defaultText,
      RuleTargetSort.delay => localizations.delay,
      RuleTargetSort.name => localizations.name,
    };
  }

  IconData _kindIcon(RuleTargetKind kind) {
    return switch (kind) {
      RuleTargetKind.builtIn => Icons.shield_outlined,
      RuleTargetKind.group => Icons.account_tree_outlined,
      RuleTargetKind.proxy => Icons.dns_outlined,
    };
  }

  String _kindLabel(BuildContext context, RuleTargetKind kind) {
    return switch (kind) {
      RuleTargetKind.builtIn => context.appLocalizations.specialProxy,
      RuleTargetKind.group => context.appLocalizations.proxyGroup,
      RuleTargetKind.proxy => context.appLocalizations.currentNode,
    };
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final activeProfile = ref.watch(currentProfileProvider)?.realLabel;
    final options = buildRuleTargetOptions(
      groups,
      activeProfile: activeProfile,
    );
    final profiles = options
        .map((option) => option.profile)
        .whereType<String>()
        .where((profile) => profile.isNotEmpty)
        .toSet()
        .toList();
    final delayMap = ref.watch(delayDataSourceProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final testUrl = ref.watch(realTestUrlProvider());
    final delays = <String, int?>{
      for (final option in options)
        option.name: computeProxyDelayState(
          proxyName: option.name,
          testUrl: testUrl,
          groups: groups,
          selectedMap: selectedMap,
          delayMap: delayMap,
        ).delay,
    };
    final visibleOptions = filterAndSortRuleTargets(
      options: options,
      query: _searchController.text,
      sort: _sort,
      kind: _kind,
      profile: _profile,
      delayOf: (name) => delays[name],
    );
    final colorScheme = context.colorScheme;
    final viewSize = ref.watch(viewSizeProvider);
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Expanded(child: Text(context.appLocalizations.selectRuleTarget)),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: viewSize.width.clamp(360, 680).toDouble(),
        height: viewSize.height.clamp(420, 680).toDouble(),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.appLocalizations.search,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TargetFilterButton(
                    selected: _profile == null,
                    label: context.appLocalizations.profiles,
                    icon: Icons.layers_outlined,
                    onPressed: () => setState(() => _profile = null),
                  ),
                  const SizedBox(width: 8),
                  for (final profile in profiles) ...[
                    _TargetFilterButton(
                      selected: _profile == profile,
                      label: profile,
                      icon: Icons.description_outlined,
                      onPressed: () => setState(() => _profile = profile),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _TargetFilterButton(
                          selected: _kind == null,
                          label: context.appLocalizations.allTargets,
                          icon: Icons.apps_outlined,
                          onPressed: () => setState(() => _kind = null),
                        ),
                        const SizedBox(width: 8),
                        for (final kind in RuleTargetKind.values) ...[
                          _TargetFilterButton(
                            icon: _kindIcon(kind),
                            selected: _kind == kind,
                            label: _kindLabel(context, kind),
                            onPressed: () => setState(() => _kind = kind),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<RuleTargetSort>(
                  tooltip: context.appLocalizations.sort,
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (context) => [
                    for (final sort in RuleTargetSort.values)
                      PopupMenuItem(
                        value: sort,
                        child: Row(
                          children: [
                            if (_sort == sort)
                              const Icon(Icons.check_rounded, size: 18)
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 10),
                            Text(_sortLabel(context, sort)),
                          ],
                        ),
                      ),
                  ],
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_vert_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(_sortLabel(context, _sort)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.appLocalizations.delayTest,
                  onPressed: _testing
                      ? null
                      : () async {
                          final unique = <String, Proxy>{};
                          for (final group in groups) {
                            for (final proxy in group.all) {
                              unique[proxy.name] = proxy;
                            }
                          }
                          setState(() => _testing = true);
                          try {
                            await delayTest(unique.values.toList());
                          } finally {
                            if (mounted) setState(() => _testing = false);
                          }
                        },
                  icon: _testing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibleOptions.isEmpty
                  ? NullStatus(label: context.appLocalizations.noData)
                  : ListView.separated(
                      itemCount: visibleOptions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final option = visibleOptions[index];
                        final selected = option.name == widget.value;
                        final delay = delays[option.name];
                        return Material(
                          color: selected
                              ? colorScheme.secondaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            leading: Icon(
                              _kindIcon(option.kind),
                              color: selected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            title: EmojiText(
                              option.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: selected
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (option.profile != null) option.profile!,
                                _kindLabel(context, option.kind),
                              ].join(' · '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (option.kind != RuleTargetKind.builtIn)
                                  Text(
                                    delay == null || delay == 0
                                        ? '--'
                                        : delay > 0
                                        ? '$delay ms'
                                        : context.appLocalizations.timeout,
                                    style: context.textTheme.labelMedium
                                        ?.copyWith(
                                          color: utils.getDelayColor(
                                            delay == 0 ? null : delay,
                                          ),
                                        ),
                                  ),
                                if (selected) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.check_circle_rounded),
                                ],
                              ],
                            ),
                            onTap: () => Navigator.of(context).pop(option.name),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetFilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _TargetFilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
