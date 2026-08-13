import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/clash_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    });

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
    });

    test('extracts rules from the previous generated script', () async {
      final script = buildRulesOverrideScript([
        'DOMAIN-SUFFIX,legacy.example,DIRECT',
        'DOMAIN,old.example,REJECT',
      ]);

      expect(await extractRulesFromOverrideScript(script), [
        'DOMAIN-SUFFIX,legacy.example,DIRECT',
        'DOMAIN,old.example,REJECT',
      ]);
    });
  });
}
