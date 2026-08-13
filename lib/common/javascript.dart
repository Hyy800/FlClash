import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:flutter_js/flutter_js.dart';

String buildRulesOverrideScript(Iterable<String> rules) {
  final encodedRules = const JsonEncoder.withIndent(
    '  ',
  ).convert(rules.toList());
  return '''
function main(config) {
  const newRules = $encodedRules;
  const oldRules = Array.isArray(config.rules) ? config.rules : [];
  config.rules = newRules.concat(oldRules);
  return config;
}
''';
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
