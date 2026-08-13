import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/overwrite/rule_usage.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates network speed and traffic for a matching rule', () {
    const rule = Rule(
      id: 1,
      ruleAction: RuleAction.DOMAIN,
      content: 'example.com',
      ruleTarget: 'DIRECT',
    );
    final usage = buildRuleUsage(
      [rule],
      [
        TrackerInfo(
          id: 'request-1',
          upload: 1024,
          download: 2048,
          uploadSpeed: 128,
          downloadSpeed: 256,
          start: DateTime(2026),
          metadata: const Metadata(network: 'tcp'),
          chains: const ['DIRECT'],
          rule: 'Domain',
          rulePayload: 'example.com',
        ),
      ],
    )[rule.id]!;

    expect(usage.networks, {'TCP'});
    expect(usage.totalTraffic, 3072);
    expect(usage.currentSpeed, 384);
    expect(usage.requestCount, 1);
  });

  test('matches application rules from process metadata', () {
    const rule = Rule(
      id: 2,
      ruleAction: RuleAction.PROCESS_PATH,
      content: r'C:\Apps\Player.exe',
      ruleTarget: 'Tokyo',
    );
    final usage = buildRuleUsage(
      [rule],
      [
        TrackerInfo(
          id: 'request-2',
          upload: 10,
          download: 20,
          start: DateTime(2026),
          metadata: const Metadata(
            network: 'udp',
            processPath: r'C:\Apps\Player.exe',
          ),
          chains: const ['Tokyo'],
          rule: 'ProcessPath',
          rulePayload: '',
        ),
      ],
    )[rule.id]!;

    expect(usage.networks, {'UDP'});
    expect(usage.totalTraffic, 30);
  });

  test('samples real speed and keeps total after a connection closes', () {
    const rule = Rule(
      id: 3,
      ruleAction: RuleAction.DOMAIN,
      content: 'example.com',
      ruleTarget: 'DIRECT',
    );
    final accumulator = RuleUsageAccumulator();
    final start = DateTime(2026);

    TrackerInfo connection(int traffic) => TrackerInfo(
      id: 'request-3',
      upload: traffic ~/ 3,
      download: traffic - traffic ~/ 3,
      start: start,
      metadata: const Metadata(network: 'tcp'),
      chains: const ['DIRECT'],
      rule: 'Domain',
      rulePayload: 'example.com',
    );

    final initial = accumulator.sample(
      rules: const [rule],
      connections: [connection(300)],
      now: start,
    )[rule.id]!;
    expect(initial.totalTraffic, 300);
    expect(initial.currentSpeed, 0);
    expect(initial.requestCount, 1);

    final next = accumulator.sample(
      rules: const [rule],
      connections: [connection(900)],
      now: start.add(const Duration(seconds: 1)),
    )[rule.id]!;
    expect(next.totalTraffic, 900);
    expect(next.currentSpeed, 600);

    final closed = accumulator.sample(
      rules: const [rule],
      connections: const [],
      now: start.add(const Duration(seconds: 2)),
    )[rule.id]!;
    expect(closed.totalTraffic, 900);
    expect(closed.currentSpeed, 0);
    expect(closed.requestCount, 1);

    accumulator.clear();
    final cleared = accumulator.sample(
      rules: const [rule],
      connections: const [],
      now: start.add(const Duration(seconds: 3)),
    )[rule.id]!;
    expect(cleared.totalTraffic, 0);
    expect(cleared.requestCount, 0);
  });

  test('matches the camel-case rule type returned by the Mihomo core', () {
    const rule = Rule(
      id: 4,
      ruleAction: RuleAction.DOMAIN_SUFFIX,
      content: 'c.emby.wtf',
      ruleTarget: 'CN Taiwan 01',
    );
    final accumulator = RuleUsageAccumulator();
    final usage = accumulator.sample(
      rules: const [rule],
      connections: [
        TrackerInfo(
          id: 'real-core-connection',
          upload: 2048,
          download: 4096,
          start: DateTime(2026),
          metadata: const Metadata(network: 'tcp', host: 'c.emby.wtf'),
          chains: const ['CN Taiwan 01'],
          rule: 'DomainSuffix',
          rulePayload: 'c.emby.wtf',
        ),
      ],
      now: DateTime(2026),
    )[rule.id]!;

    expect(usage.networks, {'TCP'});
    expect(usage.totalTraffic, 6144);
    expect(usage.requestCount, 1);
  });
}
