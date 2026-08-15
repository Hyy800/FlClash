import 'dart:async';

import 'package:fl_clash/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delay tests restore the official 100 request concurrency', () async {
    final release = Completer<void>();
    final firstWaveStarted = Completer<void>();
    var active = 0;
    var maxActive = 0;
    var started = 0;

    final operation = runProxyDelayTests(List.generate(101, (index) => index), (
      _,
    ) async {
      active++;
      started++;
      if (active > maxActive) maxActive = active;
      if (started == proxyDelayTestMaxConcurrent) {
        firstWaveStarted.complete();
      }
      await release.future;
      active--;
    });

    await firstWaveStarted.future.timeout(const Duration(seconds: 1));
    expect(started, proxyDelayTestMaxConcurrent);
    expect(maxActive, proxyDelayTestMaxConcurrent);

    release.complete();
    await operation;
    expect(started, 101);
  });
}
