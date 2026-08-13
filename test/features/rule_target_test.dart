import 'package:fl_clash/features/overwrite/rule_target.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final options = [
    const RuleTargetOption(
      name: 'DIRECT',
      kind: RuleTargetKind.builtIn,
      order: 0,
    ),
    const RuleTargetOption(
      name: 'Tokyo 02',
      kind: RuleTargetKind.proxy,
      order: 1,
    ),
    const RuleTargetOption(
      name: 'Tokyo 01',
      kind: RuleTargetKind.proxy,
      order: 2,
    ),
  ];

  test('builds unique targets and never exposes MATCH', () {
    final result = buildRuleTargetOptions([
      const Group(
        name: 'Auto',
        type: GroupType.Selector,
        all: [
          Proxy(name: 'Tokyo 01', type: 'ss'),
          Proxy(name: 'Tokyo 01', type: 'ss'),
          Proxy(name: 'MATCH', type: 'ss'),
        ],
      ),
    ]);

    expect(result.map((option) => option.name), [
      'DIRECT',
      'REJECT',
      'Auto',
      'Tokyo 01',
    ]);
  });

  test('searches targets without changing original order', () {
    final result = filterAndSortRuleTargets(
      options: options,
      query: 'tokyo',
      sort: RuleTargetSort.original,
    );

    expect(result.map((option) => option.name), ['Tokyo 02', 'Tokyo 01']);
  });

  test('sorts measured nodes by delay and unmeasured nodes last', () {
    final delays = {'Tokyo 02': 240, 'Tokyo 01': 80};
    final result = filterAndSortRuleTargets(
      options: options,
      query: '',
      sort: RuleTargetSort.delay,
      kind: RuleTargetKind.proxy,
      profile: null,
      delayOf: (name) => delays[name],
    );

    expect(result.map((option) => option.name), ['Tokyo 01', 'Tokyo 02']);
  });

  test('filters nodes by profile source', () {
    final sourcedOptions = [
      const RuleTargetOption(
        name: '[Office] Tokyo',
        kind: RuleTargetKind.proxy,
        order: 0,
        profile: 'Office',
      ),
      const RuleTargetOption(
        name: '[Home] Tokyo',
        kind: RuleTargetKind.proxy,
        order: 1,
        profile: 'Home',
      ),
    ];
    final result = filterAndSortRuleTargets(
      options: sourcedOptions,
      query: '',
      sort: RuleTargetSort.original,
      profile: 'Office',
    );

    expect(result.map((option) => option.name), ['[Office] Tokyo']);
  });

  test('sorts targets by name', () {
    final result = filterAndSortRuleTargets(
      options: options,
      query: '',
      sort: RuleTargetSort.name,
    );

    expect(result.map((option) => option.name), [
      'DIRECT',
      'Tokyo 01',
      'Tokyo 02',
    ]);
  });
}
