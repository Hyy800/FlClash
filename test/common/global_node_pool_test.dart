import 'dart:io';

import 'package:fl_clash/common/global_node_pool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flattens provider caches so remote failures stay isolated', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flclash-global-provider-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = File('${directory.path}\\provider.yaml');
    await cache.writeAsString('''
proxies:
  - name: Tokyo
    type: ss
    server: example.com
    port: 443
    cipher: aes-128-gcm
    password: test
''');
    final source = await isolateGlobalProfileSource(
      GlobalProfileSource(
        profileId: 9,
        label: 'Remote',
        config: {
          'proxy-providers': {
            'sub': {
              'type': 'file',
              'path': cache.path,
              'override': {'additional-prefix': 'P-'},
            },
          },
          'proxy-groups': [
            {
              'name': 'Select',
              'type': 'select',
              'use': ['sub'],
            },
          ],
        },
      ),
      profilesPath: directory.path,
    );

    expect(source.config['proxy-providers'], isEmpty);
    expect((source.config['proxies'] as List).single['name'], 'P-Tokyo');
    final group = (source.config['proxy-groups'] as List).single as Map;
    expect(group['proxies'], ['P-Tokyo']);
    expect(group.containsKey('use'), false);
  });

  test(
    'ignores a corrupt provider cache without keeping the provider',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flclash-broken-provider-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final cache = File('${directory.path}\\provider.yaml');
      await cache.writeAsString('proxies: [broken: yaml');
      final source = await isolateGlobalProfileSource(
        GlobalProfileSource(
          profileId: 10,
          label: 'Broken',
          config: {
            'proxy-providers': {
              'sub': {'type': 'file', 'path': cache.path},
            },
          },
        ),
        profilesPath: directory.path,
      );

      expect(source.config['proxy-providers'], isEmpty);
      expect(source.config['proxies'], isEmpty);
    },
  );

  test('imports direct nodes with stable profile namespaces', () {
    final result = buildGlobalNodePool(
      activeConfig: {
        'proxies': [
          {'name': 'Current', 'type': 'direct'},
        ],
        'proxy-groups': [],
      },
      sources: const [
        GlobalProfileSource(
          profileId: 2,
          label: 'Office',
          config: {
            'proxies': [
              {'name': 'Tokyo', 'type': 'ss', 'server': 'example.com'},
              {'name': 'Relay', 'type': 'ss', 'dialer-proxy': 'Tokyo'},
            ],
            'proxy-groups': [
              {
                'name': 'Auto',
                'type': 'select',
                'proxies': ['Tokyo', 'Relay'],
              },
            ],
          },
        ),
      ],
      profilesPath: r'C:\profiles',
    );

    final proxies = result.config['proxies'] as List;
    expect(proxies.map((item) => item['name']), [
      'Current',
      '[Office] Tokyo',
      '[Office] Relay',
    ]);
    expect(proxies.last['dialer-proxy'], '[Office] Tokyo');
    final groups = result.config['proxy-groups'] as List;
    expect(groups, hasLength(2));
    expect(groups.first['name'], '[Office] Auto');
    expect(groups.first['hidden'], true);
    expect(groups.first['proxies'], ['[Office] Tokyo', '[Office] Relay']);
    expect(groups.last['name'], '[Office] · ALL');
    expect(groups.last['proxies'], ['[Office] Tokyo', '[Office] Relay']);
    expect(result.targetAliases['Tokyo'], ['[Office] Tokyo']);
  });

  test('clones providers with prefixes and hidden loading groups', () {
    final result = buildGlobalNodePool(
      activeConfig: const {},
      sources: const [
        GlobalProfileSource(
          profileId: 3,
          label: 'Remote',
          config: {
            'proxy-providers': {
              'sub': {'type': 'http', 'url': 'https://example.com/sub'},
            },
          },
        ),
      ],
      profilesPath: r'C:\profiles',
    );

    final providers = result.config['proxy-providers'] as Map;
    expect(providers, hasLength(1));
    final provider = providers.values.single as Map;
    expect(provider['override']['additional-prefix'], '[Remote] ');
    expect(provider['path'], contains(r'providers\3\proxies'));
    final groups = result.config['proxy-groups'] as List;
    expect(groups.single['name'], '[Remote] · ALL');
    expect(groups.single['use'], [providers.keys.single]);
  });

  test('skips a broken profile without contaminating valid sources', () {
    final result = buildGlobalNodePoolSafely(
      activeConfig: const {},
      sources: const [
        GlobalProfileSource(
          profileId: 1,
          label: 'Broken',
          config: {'proxies': 'not-a-list'},
        ),
        GlobalProfileSource(
          profileId: 2,
          label: 'Office',
          config: {
            'proxies': [
              {'name': 'Tokyo', 'type': 'ss'},
            ],
          },
        ),
      ],
      profilesPath: r'C:\profiles',
    );

    expect(result.skippedProfileIds, {1});
    expect(
      (result.result.config['proxies'] as List).single['name'],
      '[Office] Tokyo',
    );
    expect(result.result.targetAliases['Tokyo'], ['[Office] Tokyo']);
  });

  test('keeps duplicate profile labels independently addressable', () {
    final result = buildGlobalNodePoolSafely(
      activeConfig: const {},
      sources: const [
        GlobalProfileSource(
          profileId: 10,
          label: 'Office',
          config: {
            'proxies': [
              {'name': 'Tokyo', 'type': 'ss'},
            ],
          },
        ),
        GlobalProfileSource(
          profileId: 11,
          label: 'Office',
          config: {
            'proxies': [
              {'name': 'Tokyo', 'type': 'ss'},
            ],
          },
        ),
      ],
      profilesPath: r'C:\profiles',
    );

    expect(result.result.targetAliases['Tokyo'], [
      '[Office · 10] Tokyo',
      '[Office · 11] Tokyo',
    ]);
  });

  test('rolls back a source rejected after it is merged', () async {
    final result = await buildValidatedGlobalNodePool(
      activeConfig: const {},
      sources: const [
        GlobalProfileSource(
          profileId: 1,
          label: 'Broken',
          config: {
            'proxies': [
              {'name': 'Bad', 'type': 'unsupported'},
            ],
          },
        ),
        GlobalProfileSource(
          profileId: 2,
          label: 'Good',
          config: {
            'proxies': [
              {'name': 'Tokyo', 'type': 'ss'},
            ],
          },
        ),
      ],
      profilesPath: r'C:\profiles',
      validate: (config) async => !(config['proxies'] as List).any(
        (proxy) => proxy['type'] == 'unsupported',
      ),
    );

    expect(result.skippedProfileIds, {1});
    expect(
      (result.result.config['proxies'] as List).single['name'],
      '[Good] Tokyo',
    );
  });
}
