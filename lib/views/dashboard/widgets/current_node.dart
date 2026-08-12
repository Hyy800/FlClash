import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

({String groupName, String nodeName}) resolveCurrentNode({
  required Mode mode,
  required List<Group> groups,
  required Map<String, String> selectedMap,
  String? currentGroupName,
}) {
  if (mode == Mode.direct) {
    final direct = Intl.message(Mode.direct.name);
    return (groupName: direct, nodeName: direct);
  }

  final visibleGroups = groups.where((group) => group.hidden != true).toList();
  if (visibleGroups.isEmpty) {
    return (groupName: '', nodeName: '');
  }

  Group? currentGroup;
  if (mode == Mode.global) {
    currentGroup = groups.getGroup(GroupName.GLOBAL.name);
  } else if (currentGroupName != null) {
    currentGroup = visibleGroups.getGroup(currentGroupName);
  }
  currentGroup ??= visibleGroups.firstWhere(
    (group) => group.name != GroupName.GLOBAL.name,
    orElse: () => visibleGroups.first,
  );

  final selectedState = computeRealSelectedProxyState(
    currentGroup.name,
    groups: groups,
    selectedMap: selectedMap,
  );
  final selectedName = selectedState.proxyName == currentGroup.name
      ? currentGroup.getCurrentSelectedName(
          selectedMap[currentGroup.name] ?? '',
        )
      : selectedState.proxyName;
  return (groupName: currentGroup.name, nodeName: selectedName);
}

class CurrentNode extends ConsumerWidget {
  const CurrentNode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final groups = ref.watch(groupsProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final currentGroupName = ref.watch(
      currentProfileProvider.select((profile) => profile?.currentGroupName),
    );
    final currentNode = resolveCurrentNode(
      mode: mode,
      groups: groups,
      selectedMap: selectedMap,
      currentGroupName: currentGroupName,
    );
    final hasNode = currentNode.nodeName.isNotEmpty;

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: hasNode && mode != Mode.direct
            ? () {
                ref
                    .read(currentPageLabelProvider.notifier)
                    .toPage(PageLabel.proxies);
              }
            : null,
        info: Info(
          label: context.appLocalizations.currentNode,
          iconData: Icons.hub_rounded,
        ),
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(top: 2, bottom: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: TooltipText(
                  text: Text(
                    hasNode
                        ? currentNode.nodeName
                        : context.appLocalizations.noData,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
                  ),
                ),
              ),
              if (currentNode.groupName.isNotEmpty) ...[
                const SizedBox(height: 3),
                TooltipText(
                  text: Text(
                    currentNode.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
