import 'dart:io';

import 'package:fl_clash/features/overwrite/rule_traffic_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flclash_rule_traffic_');
    path = '${directory.path}${Platform.pathSeparator}rule_traffic.json';
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists cumulative rule traffic across store instances', () async {
    final first = RuleTrafficStore();
    await first.initialize(path);
    first.scheduleSave({1: 1024, 2: 2048});
    await first.flush();

    final second = RuleTrafficStore();
    await second.initialize(path);

    expect(second.totals, {1: 1024, 2: 2048});
    expect(await File('$path.tmp').exists(), false);
  });

  test('flush saves the newest throttled totals', () async {
    final store = RuleTrafficStore();
    await store.initialize(path);
    store.scheduleSave({1: 100});
    store.scheduleSave({1: 300});

    await store.flush();

    final restored = RuleTrafficStore();
    await restored.initialize(path);
    expect(restored.totals, {1: 300});
  });

  test('keeps malformed traffic data untouched', () async {
    final file = File(path);
    await file.writeAsString('{invalid', flush: true);
    final store = RuleTrafficStore();

    await expectLater(store.initialize(path), throwsFormatException);

    expect(await file.readAsString(), '{invalid');
  });
}
