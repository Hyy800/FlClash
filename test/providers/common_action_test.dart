import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

class _TestCommonAction extends CommonAction {
  int connectionsCalls = 0;

  @override
  Future<Traffic> getCurrentTraffic(bool onlyStatisticsProxy) async {
    return const Traffic(up: 10, down: 20);
  }

  @override
  Future<Traffic> getCurrentTotalTraffic(bool onlyStatisticsProxy) async {
    return const Traffic(up: 100, down: 200);
  }

  @override
  Future<List<TrackerInfo>> getCurrentConnections() async {
    connectionsCalls += 1;
    return [
      TrackerInfo(
        id: 'connection-1',
        upload: 100,
        download: 200,
        start: DateTime(2026),
        metadata: const Metadata(network: 'tcp'),
        chains: const ['DIRECT'],
        rule: 'Domain',
        rulePayload: 'example.com',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('traffic refresh samples live connections for matching rules', () async {
    const rule = Rule(
      id: 1,
      ruleAction: RuleAction.DOMAIN,
      content: 'example.com',
      ruleTarget: 'DIRECT',
    );
    final container = ProviderContainer(
      overrides: [
        globalRulesProvider.overrideWithBuild((_, _) => const [rule]),
        commonActionProvider.overrideWith(_TestCommonAction.new),
      ],
    );
    addTearDown(container.dispose);
    final action =
        container.read(commonActionProvider.notifier) as _TestCommonAction;

    await action.updateTraffic();

    final usage = container.read(ruleUsagesProvider)[rule.id]!;
    expect(usage.sessionTraffic, 300);
    expect(usage.totalTraffic, 300);
    expect(
      container.read(trafficsProvider).list.last,
      const Traffic(up: 10, down: 20),
    );
    expect(
      container.read(totalTrafficProvider),
      const Traffic(up: 100, down: 200),
    );
    expect(action.connectionsCalls, 1);
  });
}
