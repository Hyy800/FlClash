import 'dart:math';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

class RuleUsage {
  final Set<String> networks;
  final int totalTraffic;
  final int currentSpeed;
  final int requestCount;

  const RuleUsage({
    this.networks = const {},
    this.totalTraffic = 0,
    this.currentSpeed = 0,
    this.requestCount = 0,
  });
}

class RuleUsageAccumulator {
  final Map<String, int> _previousConnectionTraffic = {};
  final Map<int, int> _totalTraffic = {};
  final Map<int, Set<String>> _networks = {};
  final Map<int, Set<String>> _requestIds = {};
  DateTime? _previousSampleTime;

  Map<int, RuleUsage> sample({
    required Iterable<Rule> rules,
    required Iterable<TrackerInfo> connections,
    required DateTime now,
  }) {
    final ruleList = rules.toList();
    final elapsedMicros = _previousSampleTime == null
        ? 0
        : max(now.difference(_previousSampleTime!).inMicroseconds, 1);
    final currentConnectionTraffic = <String, int>{};
    final currentSpeeds = <int, int>{};
    for (final connection in connections) {
      final connectionTraffic = connection.upload + connection.download;
      currentConnectionTraffic[connection.id] = connectionTraffic;
      Rule? rule;
      for (final candidate in ruleList) {
        if (matchesRule(candidate, connection)) {
          rule = candidate;
          break;
        }
      }
      if (rule == null) continue;
      final previousTraffic = _previousConnectionTraffic[connection.id];
      final delta = previousTraffic == null
          ? connectionTraffic
          : max(connectionTraffic - previousTraffic, 0);
      _totalTraffic[rule.id] = (_totalTraffic[rule.id] ?? 0) + delta;
      final network = connection.metadata.network.trim().toUpperCase();
      if (network.isNotEmpty) {
        _networks.putIfAbsent(rule.id, () => <String>{}).add(network);
      }
      _requestIds.putIfAbsent(rule.id, () => <String>{}).add(connection.id);
      if (elapsedMicros > 0 && previousTraffic != null) {
        final speed = (delta * Duration.microsecondsPerSecond) ~/ elapsedMicros;
        currentSpeeds[rule.id] = (currentSpeeds[rule.id] ?? 0) + speed;
      }
    }
    _previousConnectionTraffic
      ..clear()
      ..addAll(currentConnectionTraffic);
    _previousSampleTime = now;
    return {
      for (final rule in ruleList)
        rule.id: RuleUsage(
          networks: Set.unmodifiable(_networks[rule.id] ?? const {}),
          totalTraffic: _totalTraffic[rule.id] ?? 0,
          currentSpeed: currentSpeeds[rule.id] ?? 0,
          requestCount: _requestIds[rule.id]?.length ?? 0,
        ),
    };
  }

  void clear() {
    _previousConnectionTraffic.clear();
    _totalTraffic.clear();
    _networks.clear();
    _requestIds.clear();
    _previousSampleTime = null;
  }
}

Map<int, RuleUsage> buildRuleUsage(
  Iterable<Rule> rules,
  Iterable<TrackerInfo> requests,
) {
  final result = <int, RuleUsage>{};
  final latestRequests = <String, TrackerInfo>{};
  for (final request in requests) {
    final previous = latestRequests[request.id];
    if (previous == null || request.start.isAfter(previous.start)) {
      latestRequests[request.id] = request;
    } else if (request.upload + request.download >=
        previous.upload + previous.download) {
      latestRequests[request.id] = request;
    }
  }
  for (final rule in rules) {
    final networks = <String>{};
    var totalTraffic = 0;
    var currentSpeed = 0;
    var requestCount = 0;
    for (final request in latestRequests.values) {
      if (!matchesRule(rule, request)) continue;
      final network = request.metadata.network.trim().toUpperCase();
      if (network.isNotEmpty) networks.add(network);
      totalTraffic += request.upload + request.download;
      currentSpeed += (request.uploadSpeed ?? 0) + (request.downloadSpeed ?? 0);
      requestCount += 1;
    }
    result[rule.id] = RuleUsage(
      networks: networks,
      totalTraffic: totalTraffic,
      currentSpeed: currentSpeed,
      requestCount: requestCount,
    );
  }
  return result;
}

bool matchesRule(Rule rule, TrackerInfo request) {
  if (_normalizeRuleType(request.rule) !=
      _normalizeRuleType(rule.ruleAction.value)) {
    return false;
  }
  final content = rule.realContent?.trim() ?? '';
  final payload = request.rulePayload.trim();
  if (content.toLowerCase() == payload.toLowerCase()) return true;
  return switch (rule.ruleAction) {
    RuleAction.PROCESS_PATH =>
      request.metadata.processPath.trim().toLowerCase() ==
          content.toLowerCase(),
    RuleAction.PROCESS_NAME =>
      request.metadata.process.trim().toLowerCase() == content.toLowerCase(),
    _ => false,
  };
}

String _normalizeRuleType(String value) {
  final normalized = value.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
  return switch (normalized) {
    'GEOSITE' => 'GEOSITE',
    'SRCGEOIP' => 'SRCGEOIP',
    'SRCIPASN' => 'SRCIPASN',
    'SRCIPCIDR' => 'SRCIPCIDR',
    'SRCIPSUFFIX' => 'SRCIPSUFFIX',
    'SUBRULES' => 'SUBRULE',
    _ => normalized,
  };
}
