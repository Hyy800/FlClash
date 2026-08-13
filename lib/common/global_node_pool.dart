import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'string.dart';

class GlobalProfileSource {
  final int profileId;
  final String label;
  final Map<String, dynamic> config;

  const GlobalProfileSource({
    required this.profileId,
    required this.label,
    required this.config,
  });
}

class GlobalNodePoolResult {
  final Map<String, dynamic> config;
  final Map<String, List<String>> targetAliases;
  final Set<String> targets;

  const GlobalNodePoolResult({
    required this.config,
    required this.targetAliases,
    required this.targets,
  });
}

class GlobalNodePoolSourceResult {
  final GlobalNodePoolResult result;
  final Set<int> skippedProfileIds;

  const GlobalNodePoolSourceResult({
    required this.result,
    required this.skippedProfileIds,
  });
}

Future<GlobalProfileSource> isolateGlobalProfileSource(
  GlobalProfileSource source, {
  required String profilesPath,
}) async {
  final config = _copyMap(source.config);
  final providers = Map<String, dynamic>.from(
    config['proxy-providers'] as Map? ?? const {},
  );
  if (providers.isEmpty) {
    return GlobalProfileSource(
      profileId: source.profileId,
      label: source.label,
      config: config,
    );
  }
  final proxies = List<dynamic>.from(config['proxies'] as List? ?? const []);
  final providerProxies = <String, List<Map<String, dynamic>>>{};
  final names = proxies
      .whereType<Map>()
      .map((proxy) => proxy['name'])
      .whereType<String>()
      .toSet();
  for (final entry in providers.entries) {
    if (entry.value is! Map) continue;
    final provider = Map<String, dynamic>.from(entry.value as Map);
    final candidates = <String>[];
    final providerPath = provider['path'];
    if (providerPath is String && providerPath.isNotEmpty) {
      candidates.add(
        path.isAbsolute(providerPath)
            ? providerPath
            : path.join(profilesPath, providerPath),
      );
    }
    final url = provider['url'];
    if (provider['type'] == 'http' && url is String && url.isNotEmpty) {
      candidates.add(
        path.join(
          profilesPath,
          'providers',
          source.profileId.toString(),
          'proxies',
          url.toMd5(),
        ),
      );
    }
    File? cacheFile;
    for (final candidate in candidates.toSet()) {
      final file = File(candidate);
      if (await file.exists()) {
        cacheFile = file;
        break;
      }
    }
    if (cacheFile == null) continue;
    try {
      final document = loadYaml(await cacheFile.readAsString());
      final cachedProxies = document is Map ? document['proxies'] : null;
      if (cachedProxies is! Iterable) continue;
      final override = Map<String, dynamic>.from(
        provider['override'] as Map? ?? const {},
      );
      final prefix = override['additional-prefix']?.toString() ?? '';
      final suffix = override['additional-suffix']?.toString() ?? '';
      final imported = <Map<String, dynamic>>[];
      for (final rawProxy in cachedProxies.whereType<Map>()) {
        final originalName = rawProxy['name'];
        if (originalName is! String || originalName.isEmpty) continue;
        final proxy = _copyMap(rawProxy);
        final name = '$prefix$originalName$suffix';
        proxy['name'] = name;
        for (final overrideEntry in override.entries) {
          if (const {
            'additional-prefix',
            'additional-suffix',
            'proxy-name',
          }.contains(overrideEntry.key)) {
            continue;
          }
          proxy[overrideEntry.key] = overrideEntry.value;
        }
        imported.add(proxy);
        if (names.add(name)) proxies.add(proxy);
      }
      providerProxies[entry.key] = imported;
    } catch (_) {
      // A corrupt provider cache is isolated from the active configuration.
    }
  }
  final groups = <dynamic>[];
  for (final rawGroup
      in (config['proxy-groups'] as List? ?? const []).whereType<Map>()) {
    final group = _copyMap(rawGroup);
    final members = List<String>.from(group['proxies'] as List? ?? const []);
    for (final providerName in (group['use'] as List? ?? const [])) {
      if (providerName is! String) continue;
      for (final proxy in providerProxies[providerName] ?? const []) {
        final name = proxy['name'];
        if (name is String && !members.contains(name)) members.add(name);
      }
    }
    group['proxies'] = members;
    group.remove('use');
    group['include-all-providers'] = false;
    group['include-all'] = false;
    groups.add(group);
  }
  config['proxies'] = proxies;
  config['proxy-groups'] = groups;
  config['proxy-providers'] = <String, dynamic>{};
  return GlobalProfileSource(
    profileId: source.profileId,
    label: source.label,
    config: config,
  );
}

Map<String, dynamic> _copyMap(Map value) {
  return Map<String, dynamic>.from(json.decode(json.encode(value)) as Map);
}

String _safeLabel(String label, int profileId) {
  final normalized = label.trim().replaceAll(RegExp(r'[\[\]\r\n]'), ' ');
  return normalized.isEmpty ? profileId.toString() : normalized;
}

String _alias(String namespace, String name) => '[$namespace] $name';

void _addAlias(
  Map<String, List<String>> aliases,
  String original,
  String alias,
) {
  final values = aliases.putIfAbsent(original, () => <String>[]);
  if (!values.contains(alias)) values.add(alias);
}

void _rewriteProxyReference(
  Map<String, dynamic> item,
  Map<String, String> aliases,
) {
  for (final key in const [
    'dialer-proxy',
    'detour',
    'underlying-proxy',
    'proxy',
  ]) {
    final value = item[key];
    if (value is String && aliases[value] != null) {
      item[key] = aliases[value];
    }
  }
}

GlobalNodePoolResult buildGlobalNodePool({
  required Map<String, dynamic> activeConfig,
  required Iterable<GlobalProfileSource> sources,
  required String profilesPath,
}) {
  final config = _copyMap(activeConfig);
  final proxies = List<dynamic>.from(config['proxies'] as List? ?? const []);
  final groups = List<dynamic>.from(
    config['proxy-groups'] as List? ?? const [],
  );
  final providers = Map<String, dynamic>.from(
    config['proxy-providers'] as Map? ?? const {},
  );
  final usedTargets = <String>{
    ...proxies.whereType<Map>().map((item) => item['name']).whereType<String>(),
    ...groups.whereType<Map>().map((item) => item['name']).whereType<String>(),
  };
  final targetAliases = <String, List<String>>{};
  final importedTargets = <String>{};
  final sourceList = sources.toList();
  final namespaceCounts = <String, int>{};
  for (final source in sourceList) {
    final label = _safeLabel(source.label, source.profileId);
    namespaceCounts[label] = (namespaceCounts[label] ?? 0) + 1;
  }

  for (final source in sourceList) {
    final sourceLabel = _safeLabel(source.label, source.profileId);
    final namespace = namespaceCounts[sourceLabel] == 1
        ? sourceLabel
        : '$sourceLabel · ${source.profileId}';
    final sourceProxies = source.config['proxies'] as List? ?? const [];
    final sourceGroups = source.config['proxy-groups'] as List? ?? const [];
    final sourceProviders = Map<String, dynamic>.from(
      source.config['proxy-providers'] as Map? ?? const {},
    );
    final proxyAliases = <String, String>{};
    final groupAliases = <String, String>{};
    final providerAliases = <String, String>{};

    for (final proxy in sourceProxies.whereType<Map>()) {
      final name = proxy['name'];
      if (name is! String || name.isEmpty) continue;
      final alias = _alias(namespace, name);
      proxyAliases[name] = alias;
      _addAlias(targetAliases, name, alias);
    }
    for (final group in sourceGroups.whereType<Map>()) {
      final name = group['name'];
      if (name is! String || name.isEmpty) continue;
      final alias = _alias(namespace, name);
      groupAliases[name] = alias;
      _addAlias(targetAliases, name, alias);
    }
    for (final name in sourceProviders.keys) {
      providerAliases[name] =
          '__flclash_${source.profileId}_${name.toMd5().substring(0, 10)}';
    }

    final allAliases = {...proxyAliases, ...groupAliases};
    for (final rawProxy in sourceProxies.whereType<Map>()) {
      final name = rawProxy['name'];
      final alias = name is String ? proxyAliases[name] : null;
      if (alias == null || !usedTargets.add(alias)) continue;
      final proxy = _copyMap(rawProxy)..['name'] = alias;
      _rewriteProxyReference(proxy, allAliases);
      proxies.add(proxy);
      importedTargets.add(alias);
    }

    for (final entry in sourceProviders.entries) {
      if (entry.value is! Map) continue;
      final importedName = providerAliases[entry.key]!;
      if (providers.containsKey(importedName)) continue;
      final provider = _copyMap(entry.value as Map);
      _rewriteProxyReference(provider, allAliases);
      final providerPath = provider['path'];
      final url = provider['url'];
      if (provider['type'] == 'http' && url is String && url.isNotEmpty) {
        provider['path'] = path.join(
          profilesPath,
          'providers',
          source.profileId.toString(),
          'proxies',
          url.toMd5(),
        );
      } else if (providerPath is String &&
          providerPath.isNotEmpty &&
          !path.isAbsolute(providerPath)) {
        provider['path'] = path.join(profilesPath, providerPath);
      }
      final override = Map<String, dynamic>.from(
        provider['override'] as Map? ?? const {},
      );
      _rewriteProxyReference(override, allAliases);
      final originalPrefix = override['additional-prefix']?.toString() ?? '';
      override['additional-prefix'] = '[$namespace] $originalPrefix';
      provider['override'] = override;
      providers[importedName] = provider;
    }

    for (final rawGroup in sourceGroups.whereType<Map>()) {
      final name = rawGroup['name'];
      final alias = name is String ? groupAliases[name] : null;
      if (alias == null || !usedTargets.add(alias)) continue;
      final group = _copyMap(rawGroup)..['name'] = alias;
      final members = group['proxies'];
      if (members is List) {
        group['proxies'] = members
            .map((item) => item is String ? allAliases[item] ?? item : item)
            .toList();
      }
      final use = group['use'];
      if (use is List) {
        group['use'] = use
            .map(
              (item) => item is String ? providerAliases[item] ?? item : item,
            )
            .toList();
      }
      final includeAll = group['include-all'] == true;
      final includeAllProxies = group['include-all-proxies'] == true;
      final includeAllProviders = group['include-all-providers'] == true;
      if (includeAll || includeAllProxies) {
        final members = List<String>.from(
          group['proxies'] as List? ?? const [],
        );
        for (final proxyName in proxyAliases.values) {
          if (!members.contains(proxyName)) members.add(proxyName);
        }
        group['proxies'] = members;
        group['include-all-proxies'] = false;
      }
      if (includeAll || includeAllProviders) {
        final use = List<String>.from(group['use'] as List? ?? const []);
        for (final providerName in providerAliases.values) {
          if (!use.contains(providerName)) use.add(providerName);
        }
        group['use'] = use;
        group['include-all-providers'] = false;
      }
      group['include-all'] = false;
      group['hidden'] = true;
      groups.add(group);
      importedTargets.add(alias);
    }

    if (proxyAliases.isNotEmpty || providerAliases.isNotEmpty) {
      final groupName = '[$namespace] · ALL';
      if (usedTargets.add(groupName)) {
        groups.add({
          'name': groupName,
          'type': 'select',
          if (proxyAliases.isNotEmpty) 'proxies': proxyAliases.values.toList(),
          if (providerAliases.isNotEmpty)
            'use': providerAliases.values.toList(),
        });
        importedTargets.add(groupName);
      }
    }
  }

  config['proxies'] = proxies;
  config['proxy-groups'] = groups;
  config['proxy-providers'] = providers;
  return GlobalNodePoolResult(
    config: config,
    targetAliases: targetAliases,
    targets: importedTargets,
  );
}

GlobalNodePoolSourceResult buildGlobalNodePoolSafely({
  required Map<String, dynamic> activeConfig,
  required Iterable<GlobalProfileSource> sources,
  required String profilesPath,
}) {
  var result = GlobalNodePoolResult(
    config: _copyMap(activeConfig),
    targetAliases: const {},
    targets: const {},
  );
  final skippedProfileIds = <int>{};
  final sourceList = sources.toList();
  final labelCounts = <String, int>{};
  for (final source in sourceList) {
    final label = _safeLabel(source.label, source.profileId);
    labelCounts[label] = (labelCounts[label] ?? 0) + 1;
  }
  for (final source in sourceList) {
    try {
      final label = _safeLabel(source.label, source.profileId);
      final isolatedSource = labelCounts[label] == 1
          ? source
          : GlobalProfileSource(
              profileId: source.profileId,
              label: '$label · ${source.profileId}',
              config: source.config,
            );
      final next = buildGlobalNodePool(
        activeConfig: result.config,
        sources: [isolatedSource],
        profilesPath: profilesPath,
      );
      final aliases = <String, List<String>>{
        for (final entry in result.targetAliases.entries)
          entry.key: [...entry.value],
      };
      for (final entry in next.targetAliases.entries) {
        final values = aliases.putIfAbsent(entry.key, () => <String>[]);
        for (final value in entry.value) {
          if (!values.contains(value)) values.add(value);
        }
      }
      result = GlobalNodePoolResult(
        config: next.config,
        targetAliases: aliases,
        targets: {...result.targets, ...next.targets},
      );
    } catch (_) {
      skippedProfileIds.add(source.profileId);
    }
  }
  return GlobalNodePoolSourceResult(
    result: result,
    skippedProfileIds: skippedProfileIds,
  );
}

Future<GlobalNodePoolSourceResult> buildValidatedGlobalNodePool({
  required Map<String, dynamic> activeConfig,
  required Iterable<GlobalProfileSource> sources,
  required String profilesPath,
  required Future<bool> Function(Map<String, dynamic> config) validate,
}) async {
  var result = GlobalNodePoolResult(
    config: _copyMap(activeConfig),
    targetAliases: const {},
    targets: const {},
  );
  final skippedProfileIds = <int>{};
  final sourceList = sources.toList();
  final labelCounts = <String, int>{};
  for (final source in sourceList) {
    final label = _safeLabel(source.label, source.profileId);
    labelCounts[label] = (labelCounts[label] ?? 0) + 1;
  }
  for (final source in sourceList) {
    try {
      final label = _safeLabel(source.label, source.profileId);
      final isolatedSource = labelCounts[label] == 1
          ? source
          : GlobalProfileSource(
              profileId: source.profileId,
              label: '$label · ${source.profileId}',
              config: source.config,
            );
      final candidate = buildGlobalNodePool(
        activeConfig: result.config,
        sources: [isolatedSource],
        profilesPath: profilesPath,
      );
      if (!await validate(candidate.config)) {
        skippedProfileIds.add(source.profileId);
        continue;
      }
      final aliases = <String, List<String>>{
        for (final entry in result.targetAliases.entries)
          entry.key: [...entry.value],
      };
      for (final entry in candidate.targetAliases.entries) {
        final values = aliases.putIfAbsent(entry.key, () => <String>[]);
        for (final value in entry.value) {
          if (!values.contains(value)) values.add(value);
        }
      }
      result = GlobalNodePoolResult(
        config: candidate.config,
        targetAliases: aliases,
        targets: {...result.targets, ...candidate.targets},
      );
    } catch (_) {
      skippedProfileIds.add(source.profileId);
    }
  }
  return GlobalNodePoolSourceResult(
    result: result,
    skippedProfileIds: skippedProfileIds,
  );
}
