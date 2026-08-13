import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

int _globalRulePriority(String rule) {
  final action = rule.split(',').first.trim().toUpperCase();
  return action == 'PROCESS-PATH' || action == 'PROCESS-NAME' ? 0 : 1;
}

String buildRulesOverrideScript(
  Iterable<String> rules, {
  Iterable<String> additionalTargets = const [],
  Map<String, List<String>> targetAliases = const {},
}) {
  final orderedRules = rules.toList()
    ..sort((a, b) => _globalRulePriority(a).compareTo(_globalRulePriority(b)));
  final encodedRules = const JsonEncoder.withIndent('  ').convert(orderedRules);
  final encodedTargets = json.encode(additionalTargets.toSet().toList());
  final encodedAliases = json.encode(targetAliases);
  return '''
function main(config) {
  const newRules = $encodedRules;
  const oldRules = Array.isArray(config.rules) ? config.rules : [];
  const targetAliases = $encodedAliases;
  const availableTargets = new Set([
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'PASS',
    'COMPATIBLE',
    ...$encodedTargets
  ]);
  const proxies = Array.isArray(config.proxies) ? config.proxies : [];
  const groups = Array.isArray(config['proxy-groups'])
    ? config['proxy-groups']
    : [];
  proxies.forEach((proxy) => {
    if (proxy && typeof proxy.name === 'string') {
      availableTargets.add(proxy.name);
    }
  });
  groups.forEach((group) => {
    if (!group) return;
    if (typeof group.name === 'string') availableTargets.add(group.name);
    if (Array.isArray(group.proxies)) {
      group.proxies.forEach((name) => {
        if (typeof name === 'string') availableTargets.add(name);
      });
    }
  });
  const validRules = newRules.map((rule) => {
    if (typeof rule !== 'string') return false;
    const parts = rule.split(',').map((part) => part.trim());
    while (
      parts.length > 0 &&
      ['src', 'no-resolve'].includes(parts[parts.length - 1])
    ) {
      parts.pop();
    }
    const target = parts[parts.length - 1];
    if (target === 'MATCH') return null;
    if (availableTargets.has(target)) return rule;
    const aliases = Array.isArray(targetAliases[target])
      ? targetAliases[target]
      : [];
    const replacement = aliases.find((name) => availableTargets.has(name));
    if (!replacement) return null;
    const rawParts = rule.split(',');
    let targetIndex = rawParts.length - 1;
    while (
      targetIndex > 0 &&
      ['src', 'no-resolve'].includes(rawParts[targetIndex].trim())
    ) {
      targetIndex -= 1;
    }
    rawParts[targetIndex] = replacement;
    return rawParts.join(',');
  }).filter(Boolean);
  config.rules = validRules.concat(oldRules);
  return config;
}

''';
}

Future<Set<String>> loadProxyProviderTargets(
  Map<String, dynamic> config, {
  required String profilesPath,
}) async {
  final providers = config['proxy-providers'];
  if (providers is! Map) return {};
  final targets = <String>{};
  for (final provider in providers.values) {
    if (provider is! Map) continue;
    final providerPath = provider['path'];
    if (providerPath is! String || providerPath.isEmpty) continue;
    final candidates = [
      providerPath,
      if (!path.isAbsolute(providerPath)) path.join(profilesPath, providerPath),
    ];
    File? providerFile;
    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        providerFile = file;
        break;
      }
    }
    if (providerFile == null) continue;
    try {
      final document = loadYaml(await providerFile.readAsString());
      final proxies = document is Map ? document['proxies'] : null;
      if (proxies is! Iterable) continue;
      final override = provider['override'];
      final prefix = override is Map
          ? override['additional-prefix']?.toString() ?? ''
          : '';
      final suffix = override is Map
          ? override['additional-suffix']?.toString() ?? ''
          : '';
      for (final proxy in proxies) {
        final name = proxy is Map ? proxy['name'] : null;
        if (name is String && name.isNotEmpty) {
          targets.add('$prefix$name$suffix');
        }
      }
    } catch (_) {
      // A broken provider is reported by the core; it must not break rule setup.
    }
  }
  return targets;
}

Future<Map<String, dynamic>> handleEvaluate(
  String scriptContent,
  Map<String, dynamic> config,
) async {
  if (config['proxy-providers'] == null) {
    config['proxy-providers'] = {};
  }
  final configJs = json.encode(config);
  final runtime = getJavascriptRuntime();
  final res = await runtime.evaluateAsync('''
      $scriptContent
      main($configJs)
    ''');
  if (res.isError) {
    throw res.stringResult;
  }
  final value = switch (res.rawResult is ffi.Pointer) {
    true => runtime.convertValue<Map<String, dynamic>>(res),
    false => Map<String, dynamic>.from(res.rawResult),
  };
  return value ?? config;
}

Future<List<String>> extractRulesFromOverrideScript(
  String scriptContent,
) async {
  const marker = '__FLCLASH_GLOBAL_RULES_MARKER__';
  final config = await handleEvaluate(scriptContent, {
    'rules': [marker],
  });
  final rules = config['rules'];
  if (rules is! List) {
    return [];
  }
  final markerIndex = rules.indexOf(marker);
  if (markerIndex < 0) {
    return [];
  }
  return rules
      .take(markerIndex)
      .whereType<String>()
      .where((rule) => rule.split(',').length >= 3)
      .toList();
}
