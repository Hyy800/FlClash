import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'item.dart';

class RequestsView extends ConsumerStatefulWidget {
  const RequestsView({super.key});

  @override
  ConsumerState<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends ConsumerState<RequestsView> {
  final _requestsStateNotifier = ValueNotifier<TrackerInfosState>(
    const TrackerInfosState(),
  );
  List<TrackerInfo> _requests = [];
  late final ScrollController _scrollController;

  void _onSearch(String value) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      query: value,
    );
  }

  void _onKeywordsUpdate(List<String> keywords) {
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      keywords: keywords,
    );
  }

  @override
  void initState() {
    super.initState();
    _requests = ref.read(requestsProvider).list;
    _scrollController = ScrollController(initialScrollOffset: double.maxFinite);
    _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
      trackerInfos: _requests,
    );
    ref.listenManual(requestsProvider.select((state) => VM(state.list)), (
      prev,
      next,
    ) {
      _requests = next.a;
      updateRequestsThrottler();
    });
  }

  @override
  void dispose() {
    _requestsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void updateRequestsThrottler() {
    throttler.call(FunctionTag.requests, () {
      if (!mounted) {
        return;
      }
      final isEquality = trackerInfoListEquality.equals(
        _requests,
        _requestsStateNotifier.value.trackerInfos,
      );
      if (isEquality) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestsStateNotifier.value = _requestsStateNotifier.value.copyWith(
            trackerInfos: _requests,
          );
        }
      });
    }, duration: commonDuration);
  }

  ({RuleAction action, String content})? _getRuleSource(
    TrackerInfo trackerInfo,
  ) {
    var host = trackerInfo.metadata.host.trim();
    if (host.isEmpty) {
      host = Uri.tryParse(trackerInfo.desc)?.host.trim() ?? '';
    }
    final parsedHost = InternetAddress.tryParse(host);
    if (host.isNotEmpty && parsedHost == null) {
      return (action: RuleAction.DOMAIN, content: host);
    }
    final address = parsedHost?.address.isNotEmpty == true
        ? parsedHost!.address
        : trackerInfo.metadata.destinationIP.trim();
    final parsedAddress = InternetAddress.tryParse(address);
    if (parsedAddress == null) return null;
    return (
      action: parsedAddress.type == InternetAddressType.IPv6
          ? RuleAction.IP_CIDR6
          : RuleAction.IP_CIDR,
      content:
          '${parsedAddress.address}/${parsedAddress.type == InternetAddressType.IPv6 ? 128 : 32}',
    );
  }

  Future<void> _showRequestMenu(
    Offset globalPosition,
    TrackerInfo trackerInfo,
  ) async {
    final source = _getRuleSource(trackerInfo);
    if (source == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = overlay.globalToLocal(globalPosition);
    final action = await showMenu<String>(
      context: context,
      color: context.colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'add_rule',
          child: Row(
            children: [
              const Icon(Icons.add_road_rounded),
              const SizedBox(width: 10),
              Text(context.appLocalizations.addRule),
            ],
          ),
        ),
      ],
    );
    if (action != 'add_rule' || !mounted) return;
    await _showAddRoutingRule(source);
  }

  Future<void> _showAddRoutingRule(
    ({RuleAction action, String content}) source,
  ) async {
    final profileId = ref.read(currentProfileIdProvider);
    final targets = <String>{
      ...RuleTarget.baseTargets,
      ...ref.read(currentGroupsStateProvider).value.map((group) => group.name),
    }.toList();
    final draft = await showDialog<_RoutingRuleDraft>(
      context: context,
      builder: (context) =>
          _AddRoutingRuleDialog(content: source.content, targets: targets),
    );
    if (draft == null || !mounted) return;
    final rule = Rule(
      id: snowflake.id,
      ruleAction: source.action,
      content: source.content,
      ruleTarget: draft.target,
    );
    if (profileId == null) return;
    ref.read(profileAddedRulesProvider(profileId).notifier).put(rule);
    ref
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(silence: true, force: true);
    context.showNotifier(context.appLocalizations.addRule);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.requests,
      searchState: AppBarSearchState(onSearch: _onSearch),
      onKeywordsUpdate: _onKeywordsUpdate,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _requestsStateNotifier,
        builder: (_, state, _) {
          final autoScrollToEnd = state.autoScrollToEnd;
          return FadeRotationScaleBox(
            child: FloatingActionButton(
              key: ValueKey(autoScrollToEnd),
              onPressed: () {
                _requestsStateNotifier.value = _requestsStateNotifier.value
                    .copyWith(
                      autoScrollToEnd:
                          !_requestsStateNotifier.value.autoScrollToEnd,
                    );
              },
              child: autoScrollToEnd
                  ? const Icon(Icons.block)
                  : const Icon(Icons.vertical_align_top),
            ),
          );
        },
      ),
      body: ValueListenableBuilder<TrackerInfosState>(
        valueListenable: _requestsStateNotifier,
        builder: (context, state, _) {
          final requests = state.list;
          if (requests.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.requests),
            );
          }
          final items = requests
              .map<Widget>(
                (trackerInfo) => GestureDetector(
                  key: Key(trackerInfo.id),
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapDown: (details) {
                    _showRequestMenu(details.globalPosition, trackerInfo);
                  },
                  child: TrackerInfoItem(
                    trackerInfo: trackerInfo,
                    onClickKeyword: (value) {
                      context.commonScaffoldState?.addKeyword(value);
                    },
                    detailTitle: appLocalizations.details(
                      appLocalizations.request,
                    ),
                  ),
                ),
              )
              .separated(const Divider(height: 0))
              .toList();
          return Align(
            alignment: Alignment.topCenter,
            child: CommonScrollBar(
              trackVisibility: false,
              controller: _scrollController,
              child: ScrollToEndBox(
                controller: _scrollController,
                dataSource: requests,
                enable: state.autoScrollToEnd,
                onCancelToEnd: () {
                  _requestsStateNotifier.value = _requestsStateNotifier.value
                      .copyWith(autoScrollToEnd: false);
                },
                child: SuperListView.builder(
                  reverse: true,
                  shrinkWrap: true,
                  physics: const NextClampingScrollPhysics(),
                  controller: _scrollController,
                  itemBuilder: (_, index) {
                    return items[index];
                  },
                  itemCount: items.length,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoutingRuleDraft {
  final String target;

  const _RoutingRuleDraft({required this.target});
}

class _AddRoutingRuleDialog extends StatefulWidget {
  final String content;
  final List<String> targets;

  const _AddRoutingRuleDialog({required this.content, required this.targets});

  @override
  State<_AddRoutingRuleDialog> createState() => _AddRoutingRuleDialogState();
}

class _AddRoutingRuleDialogState extends State<_AddRoutingRuleDialog> {
  late String _target;

  @override
  void initState() {
    super.initState();
    _target = widget.targets.firstOrNull ?? RuleTarget.DIRECT.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      title: Text(l10n.addRule),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              widget.content,
              style: context.textTheme.bodyMedium?.toJetBrainsMono,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _target,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.ruleTarget),
              items: widget.targets
                  .map(
                    (target) => DropdownMenuItem(
                      value: target,
                      child: Text(target, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _target = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _RoutingRuleDraft(target: _target)),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
