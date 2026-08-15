import 'dart:io';

import 'package:fl_clash/common/window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consumes a recent installer shutdown request', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flclash-update-shutdown-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final marker = File('${directory.path}${Platform.pathSeparator}request');
    await marker.writeAsString('update');
    final now = DateTime.now();
    await marker.setLastModified(now);

    expect(await consumeUpdateShutdownRequest(marker, now: now), isTrue);
    expect(await marker.exists(), isFalse);
  });

  test('ignores and removes a stale installer shutdown request', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flclash-stale-update-shutdown-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final marker = File('${directory.path}${Platform.pathSeparator}request');
    await marker.writeAsString('update');
    final now = DateTime.now();
    await marker.setLastModified(now.subtract(const Duration(minutes: 11)));

    expect(await consumeUpdateShutdownRequest(marker, now: now), isFalse);
    expect(await marker.exists(), isFalse);
  });
}
