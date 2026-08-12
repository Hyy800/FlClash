import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/widgets/current_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const direct = Proxy(name: 'DIRECT', type: 'Direct');
  const node = Proxy(name: 'Node A', type: 'Shadowsocks');
  const nestedGroupProxy = Proxy(name: 'Auto', type: 'Selector');
  const nestedGroup = Group(
    name: 'Auto',
    type: GroupType.Selector,
    all: [node],
  );
  const mainGroup = Group(
    name: 'Main',
    type: GroupType.Selector,
    all: [nestedGroupProxy, direct],
  );

  test('resolves nested groups to the final selected node', () {
    final result = resolveCurrentNode(
      mode: Mode.rule,
      groups: const [mainGroup, nestedGroup],
      selectedMap: const {'Main': 'Auto', 'Auto': 'Node A'},
      currentGroupName: 'Main',
    );

    expect(result.groupName, 'Main');
    expect(result.nodeName, 'Node A');
  });

  test('uses the first visible rule group when no group was viewed', () {
    final result = resolveCurrentNode(
      mode: Mode.rule,
      groups: const [mainGroup],
      selectedMap: const {'Main': 'DIRECT'},
    );

    expect(result.groupName, 'Main');
    expect(result.nodeName, 'DIRECT');
  });

  test('direct mode reports direct without any configured groups', () {
    final result = resolveCurrentNode(
      mode: Mode.direct,
      groups: const [],
      selectedMap: const {},
    );

    expect(result.groupName, isNotEmpty);
    expect(result.nodeName, result.groupName);
  });

  test('returns empty values when no groups exist in rule mode', () {
    final result = resolveCurrentNode(
      mode: Mode.rule,
      groups: const [],
      selectedMap: const {},
    );

    expect(result.groupName, isEmpty);
    expect(result.nodeName, isEmpty);
  });
}
