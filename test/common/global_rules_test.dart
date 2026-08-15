import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requiresQuickJs = !Platform.isWindows
      ? 'QuickJS test library is only bundled with the Windows test build.'
      : false;

  group('mergeProfileAddedRules', () {
    test('keeps per-profile graphical rules working', () {
      final result = mergeProfileAddedRules(
        const ['DOMAIN,profile.example,DIRECT', 'MATCH,PROXY'],
        const [
          Rule(
            id: 1,
            ruleAction: RuleAction.DOMAIN_SUFFIX,
            content: 'local.example',
            ruleTarget: 'DIRECT',
          ),
        ],
      );

      expect(result.first, 'DOMAIN-SUFFIX,local.example,DIRECT');
      expect(result.last, 'MATCH,PROXY');
    });

    test('excludes individually disabled global rules', () {
      final values = enabledRuleValues(const [
        Rule(id: 1, content: 'enabled.example', ruleTarget: 'DIRECT'),
        Rule(
          id: 2,
          content: 'disabled.example',
          ruleTarget: 'DIRECT',
          enabled: false,
        ),
      ]);

      expect(values, ['DOMAIN,enabled.example,DIRECT']);
    });
  });

  group('global JavaScript override', () {
    test('builds a script from the graphical rule list', () async {
      final script = buildRulesOverrideScript([
        'DOMAIN-SUFFIX,feemoo.com,DIRECT',
        'DOMAIN-SUFFIX,feemoo.vip,DIRECT',
      ]);
      final result = await handleEvaluate(script, {
        'rules': ['MATCH,ProfileProxy'],
      });

      expect(result['rules'], [
        'DOMAIN-SUFFIX,feemoo.com,DIRECT',
        'DOMAIN-SUFFIX,feemoo.vip,DIRECT',
        'MATCH,ProfileProxy',
      ]);
    }, skip: requiresQuickJs);

    test('places application rules before every other rule', () async {
      final script = buildRulesOverrideScript(
        [
          'DOMAIN,example.com,DIRECT',
          r'PROCESS-PATH,C:\Apps\Player.exe,Office',
        ],
        additionalTargets: ['Office'],
      );
      final result = await handleEvaluate(script, {
        'rules': ['MATCH,DIRECT'],
      });

      expect(result['rules'], [
        r'PROCESS-PATH,C:\Apps\Player.exe,Office',
        'DOMAIN,example.com,DIRECT',
        'MATCH,DIRECT',
      ]);
    }, skip: requiresQuickJs);

    test(
      'keeps node and proxy-group targets available in the profile',
      () async {
        final script = buildRulesOverrideScript([
          'DOMAIN,node.example,Tokyo 01',
          'DOMAIN,group.example,Auto Select',
        ]);
        final result = await handleEvaluate(script, {
          'proxies': [
            {'name': 'Tokyo 01'},
          ],
          'proxy-groups': [
            {
              'name': 'Auto Select',
              'proxies': ['Tokyo 01'],
            },
          ],
          'rules': ['MATCH,Auto Select'],
        });

        expect(result['rules'], [
          'DOMAIN,node.example,Tokyo 01',
          'DOMAIN,group.example,Auto Select',
          'MATCH,Auto Select',
        ]);
      },
      skip: requiresQuickJs,
    );

    test(
      'skips MATCH and targets missing from the active profile',
      () async {
        final script = buildRulesOverrideScript([
          'DOMAIN,invalid.example,MATCH',
          'DOMAIN,missing.example,Missing node',
          'DOMAIN,direct.example,DIRECT',
        ]);
        final result = await handleEvaluate(script, {
          'rules': ['MATCH,ProfileProxy'],
        });

        expect(result['rules'], [
          'DOMAIN,direct.example,DIRECT',
          'MATCH,ProfileProxy',
        ]);
      },
      skip: requiresQuickJs,
    );

    test('keeps provider nodes supplied by the provider cache', () async {
      final script = buildRulesOverrideScript(
        ['DOMAIN,provider.example,Provider node'],
        additionalTargets: ['Provider node'],
      );
      final result = await handleEvaluate(script, {
        'proxy-providers': {
          'subscription': {'type': 'http'},
        },
        'rules': ['MATCH,DIRECT'],
      });

      expect(result['rules'], [
        'DOMAIN,provider.example,Provider node',
        'MATCH,DIRECT',
      ]);
    }, skip: requiresQuickJs);

    test(
      'automatically remaps a missing target to another profile',
      () async {
        final script = buildRulesOverrideScript(
          ['DOMAIN,cross-profile.example,Tokyo'],
          additionalTargets: ['[Office] Tokyo'],
          targetAliases: {
            'Tokyo': ['[Office] Tokyo'],
          },
        );
        final result = await handleEvaluate(script, {
          'proxies': [
            {'name': '[Office] Tokyo'},
          ],
          'rules': ['MATCH,DIRECT'],
        });

        expect(result['rules'], [
          'DOMAIN,cross-profile.example,[Office] Tokyo',
          'MATCH,DIRECT',
        ]);
      },
      skip: requiresQuickJs,
    );

    test('prefers a same-name target in the active profile', () async {
      final script = buildRulesOverrideScript(
        ['DOMAIN,active.example,Tokyo'],
        additionalTargets: ['[Office] Tokyo'],
        targetAliases: {
          'Tokyo': ['[Office] Tokyo'],
        },
      );
      final result = await handleEvaluate(script, {
        'proxies': [
          {'name': 'Tokyo'},
          {'name': '[Office] Tokyo'},
        ],
        'rules': ['MATCH,DIRECT'],
      });

      expect(result['rules'], ['DOMAIN,active.example,Tokyo', 'MATCH,DIRECT']);
    }, skip: requiresQuickJs);

    test('runs after profile processing and prefixes rules', () async {
      const script = '''
function main(config) {
  const newRules = [
    "DOMAIN-SUFFIX,feemoo.com,DIRECT",
    "DOMAIN-SUFFIX,feemoo.vip,DIRECT"
  ];
  const oldRules = Array.isArray(config.rules) ? config.rules : [];
  config.rules = newRules.concat(oldRules);
  return config;
}''';
      final result = await handleEvaluate(script, {
        'rules': ['DOMAIN,profile.example,DIRECT', 'MATCH,ProfileProxy'],
      });

      expect(result['rules'], [
        'DOMAIN-SUFFIX,feemoo.com,DIRECT',
        'DOMAIN-SUFFIX,feemoo.vip,DIRECT',
        'DOMAIN,profile.example,DIRECT',
        'MATCH,ProfileProxy',
      ]);
    }, skip: requiresQuickJs);

    test('extracts rules from the previous generated script', () async {
      final script = buildRulesOverrideScript([
        'DOMAIN-SUFFIX,legacy.example,DIRECT',
        'DOMAIN,old.example,REJECT',
      ]);

      expect(await extractRulesFromOverrideScript(script), [
        'DOMAIN-SUFFIX,legacy.example,DIRECT',
        'DOMAIN,old.example,REJECT',
      ]);
    }, skip: requiresQuickJs);
  });

  test('loads node names from a local proxy-provider cache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flclash-provider-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final providerFile = File('${directory.path}\\provider.yaml');
    await providerFile.writeAsString('''
proxies:
  - name: Provider Tokyo
    type: ss
  - name: Provider Osaka
    type: vmess
''');

    final targets = await loadProxyProviderTargets({
      'proxy-providers': {
        'subscription': {'path': providerFile.path},
      },
    }, profilesPath: directory.path);

    expect(targets, {'Provider Tokyo', 'Provider Osaka'});
  });

  test('applies provider namespace overrides to cached node names', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flclash-prefixed-provider-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final providerFile = File('${directory.path}\\provider.yaml');
    await providerFile.writeAsString('''
proxies:
  - name: Tokyo
    type: ss
''');

    final targets = await loadProxyProviderTargets({
      'proxy-providers': {
        'subscription': {
          'path': providerFile.path,
          'override': {'additional-prefix': '[Office] '},
        },
      },
    }, profilesPath: directory.path);

    expect(targets, {'[Office] Tokyo'});
  });
}
