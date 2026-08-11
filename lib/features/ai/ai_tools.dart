import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ai/ai_service.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';

typedef AiToolConfirmation = Future<bool> Function(
  String action,
  String details,
);

typedef AiRoutingRuleSource = ({RuleAction action, String content});

AiRoutingRuleSource parseAiRoutingRuleSource(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    throw const FormatException('rule_value cannot be empty.');
  }

  var matchSubdomains = false;
  if (value.startsWith('*.')) {
    matchSubdomains = true;
    value = value.substring(2);
  } else if (value.startsWith('.')) {
    matchSubdomains = true;
    value = value.substring(1);
  }

  final originalCidrParts = value.split('/');
  if (!value.contains('://') && originalCidrParts.length == 2) {
    final address = InternetAddress.tryParse(originalCidrParts.first);
    if (address != null) {
      final prefix = int.tryParse(originalCidrParts.last);
      final maxPrefix = address.type == InternetAddressType.IPv6 ? 128 : 32;
      if (prefix == null || prefix < 0 || prefix > maxPrefix) {
        throw const FormatException('Invalid IP CIDR rule value.');
      }
      return (
        action: address.type == InternetAddressType.IPv6
            ? RuleAction.IP_CIDR6
            : RuleAction.IP_CIDR,
        content: '${address.address}/$prefix',
      );
    }
  }

  final uri = Uri.tryParse(
    value.contains('://') ? value : 'http://$value',
  );
  if (uri != null && uri.host.isNotEmpty) {
    final hasUrlParts = value.contains('://') ||
        value.contains('/') ||
        (uri.hasPort && InternetAddress.tryParse(value) == null);
    if (hasUrlParts) value = uri.host;
  }
  if (value.startsWith('[') && value.endsWith(']')) {
    value = value.substring(1, value.length - 1);
  }

  final cidrParts = value.split('/');
  if (cidrParts.length == 2) {
    final address = InternetAddress.tryParse(cidrParts.first);
    final prefix = int.tryParse(cidrParts.last);
    final maxPrefix = address?.type == InternetAddressType.IPv6 ? 128 : 32;
    if (address == null ||
        prefix == null ||
        prefix < 0 ||
        prefix > maxPrefix) {
      throw const FormatException('Invalid IP CIDR rule value.');
    }
    return (
      action: address.type == InternetAddressType.IPv6
          ? RuleAction.IP_CIDR6
          : RuleAction.IP_CIDR,
      content: '${address.address}/$prefix',
    );
  }

  final address = InternetAddress.tryParse(value);
  if (address != null) {
    return (
      action: address.type == InternetAddressType.IPv6
          ? RuleAction.IP_CIDR6
          : RuleAction.IP_CIDR,
      content: '${address.address}/${
          address.type == InternetAddressType.IPv6 ? 128 : 32}',
    );
  }

  value = value.toLowerCase();
  if (value.endsWith('.')) value = value.substring(0, value.length - 1);
  final domainPattern = RegExp(
    r'^(?=.{1,253}$)(?:[a-z0-9\u0080-\uFFFF](?:[a-z0-9\u0080-\uFFFF-]{0,61}[a-z0-9\u0080-\uFFFF])?\.)*[a-z0-9\u0080-\uFFFF](?:[a-z0-9\u0080-\uFFFF-]{0,61}[a-z0-9\u0080-\uFFFF])?$',
  );
  if (!domainPattern.hasMatch(value)) {
    throw const FormatException(
      'rule_value must be a valid domain, URL, IP address, or CIDR.',
    );
  }
  return (
    action: matchSubdomains ? RuleAction.DOMAIN_SUFFIX : RuleAction.DOMAIN,
    content: value,
  );
}

class AiToolExecutor {
  final AiToolConfirmation confirm;

  const AiToolExecutor({required this.confirm});

  Future<Map<String, dynamic>> execute(AiToolCall call) async {
    return switch (call.name) {
      'list_capabilities' => _listCapabilities(),
      'get_app_state' => _getAppState(),
      'list_profiles' => _listProfiles(),
      'switch_profile' => _switchProfile(call.arguments),
      'list_proxy_groups' => _listProxyGroups(),
      'switch_proxy' => _switchProxy(call.arguments),
      'test_proxy_delays' => _testProxyDelays(call.arguments),
      'add_routing_rule' => _addRoutingRule(call.arguments),
      'list_ai_skills' => _listAiSkills(),
      'import_ai_skill' => _importAiSkill(call.arguments),
      'set_running' => _setRunning(call.arguments),
      'set_global_overwrite_profile' => _setGlobalOverwriteProfile(
        call.arguments,
      ),
      'set_profile_user_agent' => _setProfileUserAgent(call.arguments),
      'update_profile_subscription' => _updateProfileSubscription(
        call.arguments,
      ),
      'rename_profile' => _renameProfile(call.arguments),
      'delete_profile' => _deleteProfile(call.arguments),
      'restart_core' => _restartCore(),
      'close_connections' => _closeConnections(),
      'refresh_proxy_groups' => _refreshProxyGroups(),
      'update_all_profiles' => _updateAllProfiles(),
      'clear_logs_and_requests' => _clearLogsAndRequests(),
      'get_profile_yaml' => _getProfileYaml(call.arguments),
      'validate_yaml' => _validateYaml(call.arguments),
      'create_profile_yaml' => _createProfileYaml(call.arguments),
      'replace_profile_yaml' => _replaceProfileYaml(call.arguments),
      'update_settings' => _updateSettings(call.arguments),
      _ => {'ok': false, 'error': 'Unknown tool: ${call.name}'},
    };
  }

  Map<String, dynamic> _listCapabilities() {
    const sensitive = {
      'set_running',
      'create_profile_yaml',
      'replace_profile_yaml',
      'update_settings',
      'delete_profile',
      'restart_core',
      'close_connections',
      'clear_logs_and_requests',
      'add_routing_rule',
      'import_ai_skill',
    };
    return {
      'ok': true,
      'capabilities': aiToolDefinitions.map((tool) {
        final function = Map<String, dynamic>.from(
          tool['function'] as Map? ?? const {},
        );
        final name = function['name']?.toString() ?? '';
        return {
          'name': name,
          'description': function['description'],
          'requires_confirmation': sensitive.contains(name),
        };
      }).toList(),
      'security_boundary':
          'No arbitrary shell, reflection, unrestricted code, or file access.',
    };
  }

  Map<String, dynamic> _getAppState() {
    final container = globalState.container;
    final patch = container.read(patchClashConfigProvider);
    final network = container.read(networkSettingProvider);
    final appSetting = container.read(appSettingProvider);
    final currentProfile = container.read(currentProfileProvider);
    return {
      'ok': true,
      'running': container.read(isStartProvider),
      'current_profile': currentProfile == null
          ? null
          : {'id': currentProfile.id, 'label': currentProfile.realLabel},
      'mode': patch.mode.name,
      'system_proxy': network.systemProxy,
      'tun': patch.tun.enable,
      'allow_lan': patch.allowLan,
      'ipv6': patch.ipv6,
      'mixed_port': patch.mixedPort,
      'global_user_agent': patch.globalUa,
      'dns': {
        'enabled': patch.dns.enable,
        'nameservers': patch.dns.nameserver,
      },
      'global_overwrite_profile_id': container.read(
        globalOverwriteProfileIdProvider,
      ),
      'application': {
        'auto_launch': appSetting.autoLaunch,
        'silent_launch': appSetting.silentLaunch,
        'auto_run': appSetting.autoRun,
        'auto_check_update': appSetting.autoCheckUpdate,
        'open_logs': appSetting.openLogs,
        'close_connections': appSetting.closeConnections,
        'animate_navigation': appSetting.isAnimateToPage,
        'theme_mode': container.read(themeSettingProvider).themeMode.name,
      },
    };
  }

  Map<String, dynamic> _listProfiles() {
    final container = globalState.container;
    final currentId = container.read(currentProfileIdProvider);
    return {
      'ok': true,
      'profiles': container
          .read(profilesProvider)
          .map(
            (profile) => {
              'id': profile.id,
              'label': profile.realLabel,
              'type': profile.type.name,
              'current': profile.id == currentId,
              'url': profile.url,
              'overwrite_type': profile.overwriteType.name,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _switchProfile(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final container = globalState.container;
    final profile = container.read(profilesProvider).getProfile(profileId);
    if (profile == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    container.read(currentProfileIdProvider.notifier).value = profileId;
    if (container.read(profilesProvider).isNotEmpty) {
      await container
          .read(setupActionProvider.notifier)
          .applyProfile(force: true);
    }
    return {'ok': true, 'profile_id': profileId, 'label': profile.realLabel};
  }

  Map<String, dynamic> _listProxyGroups() {
    final groups = globalState.container.read(currentGroupsStateProvider).value;
    return {
      'ok': true,
      'groups': groups
          .map(
            (group) => {
              'name': group.name,
              'current': group.now,
              'proxies': group.all
                  .take(200)
                  .map((proxy) => proxy.name)
                  .toList(),
              'truncated': group.all.length > 200,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _switchProxy(
    Map<String, dynamic> arguments,
  ) async {
    final groupName = _readString(arguments, 'group_name');
    final proxyName = _readString(arguments, 'proxy_name');
    final container = globalState.container;
    final group = container
        .read(currentGroupsStateProvider)
        .value
        .getGroup(groupName);
    if (group == null) {
      return {'ok': false, 'error': 'Proxy group was not found.'};
    }
    if (!group.all.any((proxy) => proxy.name == proxyName)) {
      return {'ok': false, 'error': 'Proxy node was not found in the group.'};
    }
    container
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, proxyName);
    await container
        .read(proxiesActionProvider.notifier)
        .changeProxy(groupName: groupName, proxyName: proxyName);
    return {'ok': true, 'group_name': groupName, 'proxy_name': proxyName};
  }

  Future<Map<String, dynamic>> _testProxyDelays(
    Map<String, dynamic> arguments,
  ) async {
    final container = globalState.container;
    final groups = container.read(currentGroupsStateProvider).value;
    if (groups.isEmpty) {
      return {'ok': false, 'error': 'No proxy groups are available.'};
    }
    final requestedGroup = arguments['group_name']?.toString().trim() ?? '';
    final currentGroupName = container
        .read(currentProfileProvider)
        ?.currentGroupName;
    final fallbackGroup = groups.getGroup(currentGroupName ?? '') ?? groups.first;
    final group = requestedGroup.isEmpty
        ? fallbackGroup
        : groups.getGroup(requestedGroup);
    if (group == null) {
      return {
        'ok': false,
        'error': 'Proxy group $requestedGroup was not found.',
      };
    }
    final proxyNames = arguments['proxy_names'];
    if (proxyNames != null && proxyNames is! List) {
      return {'ok': false, 'error': 'proxy_names must be an array.'};
    }
    final requestedNames = (proxyNames as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
    final proxies = group.all
        .where(
          (proxy) => requestedNames.isEmpty || requestedNames.contains(proxy.name),
        )
        .take(100)
        .toList();
    if (proxies.isEmpty) {
      return {'ok': false, 'error': 'No matching proxies were found.'};
    }
    final testUrl = container.read(realTestUrlProvider(group.testUrl));
    final results = <Map<String, dynamic>>[];
    for (final batch in proxies.batch(20)) {
      final values = await Future.wait(
        batch.map((proxy) async {
          try {
            final delay = await coreController.getDelay(testUrl, proxy.name);
            container.read(proxiesActionProvider.notifier).setDelay(delay);
            final delayValue = delay.value ?? -1;
            return <String, dynamic>{
              'name': proxy.name,
              'delay_ms': delayValue,
              'available': delayValue > 0,
            };
          } catch (error) {
            return <String, dynamic>{
              'name': proxy.name,
              'delay_ms': -1,
              'available': false,
              'error': error.toString(),
            };
          }
        }),
      );
      results.addAll(values);
    }
    results.sort((a, b) {
      final aDelay = a['delay_ms'] as int;
      final bDelay = b['delay_ms'] as int;
      if (aDelay <= 0 && bDelay > 0) return 1;
      if (bDelay <= 0 && aDelay > 0) return -1;
      return aDelay.compareTo(bDelay);
    });
    container.read(sortNumProvider.notifier).add();
    final fastest = results.where((item) => item['available'] == true).firstOrNull;
    return {
      'ok': true,
      'group_name': group.name,
      'test_url': testUrl,
      'results': results,
      'fastest': fastest,
      'tested': results.length,
      'truncated': proxies.length < group.all.length && requestedNames.isEmpty,
    };
  }

  Future<Map<String, dynamic>> _setRunning(
    Map<String, dynamic> arguments,
  ) async {
    final value = arguments['running'];
    if (value is! bool) {
      throw const FormatException('running must be a boolean.');
    }
    final current = globalState.container.read(isStartProvider);
    if (current == value) {
      return {'ok': true, 'running': current, 'changed': false};
    }
    final approved = await confirm('set_running', 'running: $value');
    if (!approved) {
      return {'ok': false, 'cancelled': true};
    }
    await globalState.container
        .read(setupActionProvider.notifier)
        .updateStatus(value);
    return {
      'ok': true,
      'running': globalState.container.read(isStartProvider),
      'changed': true,
    };
  }

  Future<Map<String, dynamic>> _addRoutingRule(
    Map<String, dynamic> arguments,
  ) async {
    final source = parseAiRoutingRuleSource(
      _readString(arguments, 'rule_value'),
    );
    final requestedTarget = _readString(arguments, 'target');
    final container = globalState.container;
    final groups = container.read(currentGroupsStateProvider).value;
    final availableTargets = <String>{
      ...RuleTarget.baseTargets,
      ...groups.map((group) => group.name),
      ...groups.expand((group) => group.all.map((proxy) => proxy.name)),
    };
    final target = availableTargets
        .where(
          (item) => item.toLowerCase() == requestedTarget.toLowerCase(),
        )
        .firstOrNull;
    if (target == null) {
      return {
        'ok': false,
        'error': 'Routing target $requestedTarget was not found.',
        'available_targets': availableTargets.take(200).toList(),
        'truncated': availableTargets.length > 200,
      };
    }

    final scope = arguments['scope']?.toString().trim().toLowerCase() ??
        'current_profile';
    if (!{'global', 'current_profile', 'profile'}.contains(scope)) {
      return {
        'ok': false,
        'error': 'scope must be global, current_profile, or profile.',
      };
    }
    int? profileId;
    if (scope != 'global') {
      profileId = scope == 'profile'
          ? _readInt(arguments, 'profile_id')
          : container.read(currentProfileIdProvider);
      if (profileId == null ||
          container.read(profilesProvider).getProfile(profileId) == null) {
        return {'ok': false, 'error': 'The target profile was not found.'};
      }
    }

    final rule = Rule(
      id: snowflake.id,
      ruleAction: source.action,
      content: source.content,
      ruleTarget: target,
      noResolve: arguments['no_resolve'] as bool? ?? false,
    );
    final existingRules = profileId == null
        ? container.read(globalRulesProvider.notifier).value
        : container.read(profileAddedRulesProvider(profileId).notifier).value;
    final duplicate = existingRules.any(
      (item) =>
          item.ruleAction == rule.ruleAction &&
          item.content == rule.content &&
          item.ruleTarget == rule.ruleTarget &&
          item.noResolve == rule.noResolve,
    );
    if (duplicate) {
      return {
        'ok': true,
        'changed': false,
        'rule': rule.rawValue,
        'scope': scope,
        if (profileId != null) 'profile_id': profileId,
      };
    }

    final approved = await confirm(
      'add_routing_rule',
      '${rule.rawValue}\nscope: $scope${
          profileId == null ? '' : '\nprofile_id: $profileId'}',
    );
    if (!approved) return {'ok': false, 'cancelled': true};
    if (profileId == null) {
      await container.read(globalRulesProvider.notifier).putAndWait(rule);
    } else {
      await container
          .read(profileAddedRulesProvider(profileId).notifier)
          .putAndWait(rule);
    }
    await container
        .read(setupActionProvider.notifier)
        .applyProfile(force: true);
    return {
      'ok': true,
      'changed': true,
      'rule': rule.rawValue,
      'rule_type': source.action.value,
      'content': source.content,
      'target': target,
      'scope': scope,
      if (profileId != null) 'profile_id': profileId,
      'applied': true,
    };
  }

  Map<String, dynamic> _listAiSkills() {
    final skills = globalState.container.read(aiSkillsProvider);
    return {
      'ok': true,
      'skills': skills
          .map(
            (skill) => {
              'id': skill.id,
              'name': skill.name,
              'enabled': skill.enabled,
              'characters': skill.content.length,
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _importAiSkill(
    Map<String, dynamic> arguments,
  ) async {
    final name = _readString(arguments, 'name');
    final content = _readString(arguments, 'content');
    if (content.length > AiSkill.maxContentLength) {
      return {'ok': false, 'error': 'Skill content is too large.'};
    }
    final approved = await confirm(
      'import_ai_skill',
      '$name\n${content.length} characters',
    );
    if (!approved) return {'ok': false, 'cancelled': true};
    final skill = await globalState.container
        .read(aiSkillsProvider.notifier)
        .importSkill(name: name, content: content);
    return {
      'ok': true,
      'skill_id': skill.id,
      'name': skill.name,
      'enabled': skill.enabled,
      'characters': skill.content.length,
    };
  }

  Future<Map<String, dynamic>> _setGlobalOverwriteProfile(
    Map<String, dynamic> arguments,
  ) async {
    final disabled = arguments['disabled'] as bool? ?? false;
    int? profileId;
    if (!disabled) {
      profileId = _readInt(arguments, 'profile_id');
      final profile = globalState.container
          .read(profilesProvider)
          .getProfile(profileId);
      if (profile == null) {
        return {'ok': false, 'error': 'Profile $profileId was not found.'};
      }
    }
    await globalState.container
        .read(globalOverwriteProfileIdProvider.notifier)
        .setValue(profileId);
    await globalState.container
        .read(setupActionProvider.notifier)
        .applyProfile(force: true);
    return {'ok': true, 'profile_id': profileId};
  }

  Future<Map<String, dynamic>> _setProfileUserAgent(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final userAgent = arguments['user_agent']?.toString().trim() ?? '';
    final container = globalState.container;
    if (container.read(profilesProvider).getProfile(profileId) == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    await container
        .read(profileUserAgentsProvider.notifier)
        .setUserAgent(profileId, userAgent);
    if (profileId == container.read(currentProfileIdProvider)) {
      await container
          .read(setupActionProvider.notifier)
          .applyProfile(force: true);
    }
    return {
      'ok': true,
      'profile_id': profileId,
      'custom_user_agent': userAgent.isNotEmpty,
    };
  }

  Future<Map<String, dynamic>> _updateProfileSubscription(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final container = globalState.container;
    final profile = container.read(profilesProvider).getProfile(profileId);
    if (profile == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    if (profile.url.isEmpty) {
      return {'ok': false, 'error': 'This profile has no subscription URL.'};
    }
    await container
        .read(profilesActionProvider.notifier)
        .updateProfile(profile, showLoading: true);
    return {'ok': true, 'profile_id': profileId};
  }

  Future<Map<String, dynamic>> _renameProfile(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final label = _readString(arguments, 'label');
    final container = globalState.container;
    final profile = container.read(profilesProvider).getProfile(profileId);
    if (profile == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    container
        .read(profilesActionProvider.notifier)
        .putProfile(profile.copyWith(label: label));
    return {'ok': true, 'profile_id': profileId, 'label': label};
  }

  Future<Map<String, dynamic>> _deleteProfile(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final container = globalState.container;
    final profile = container.read(profilesProvider).getProfile(profileId);
    if (profile == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    final approved = await confirm('delete_profile', profile.realLabel);
    if (!approved) return {'ok': false, 'cancelled': true};
    await container
        .read(profilesActionProvider.notifier)
        .deleteProfile(profileId);
    if (container.read(profilesProvider).isNotEmpty) {
      await container
          .read(setupActionProvider.notifier)
          .applyProfile(force: true);
    }
    return {'ok': true, 'profile_id': profileId};
  }

  Future<Map<String, dynamic>> _restartCore() async {
    if (!await confirm('restart_core', 'Restart the FlClash core process.')) {
      return {'ok': false, 'cancelled': true};
    }
    await globalState.container
        .read(coreActionProvider.notifier)
        .restartCore();
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _closeConnections() async {
    if (!await confirm('close_connections', 'Close all active connections.')) {
      return {'ok': false, 'cancelled': true};
    }
    await coreController.closeConnections();
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _refreshProxyGroups() async {
    await globalState.container
        .read(proxiesActionProvider.notifier)
        .updateGroups();
    return _listProxyGroups();
  }

  Future<Map<String, dynamic>> _updateAllProfiles() async {
    await globalState.container
        .read(profilesActionProvider.notifier)
        .updateProfiles();
    return _listProfiles();
  }

  Future<Map<String, dynamic>> _clearLogsAndRequests() async {
    if (!await confirm(
      'clear_logs_and_requests',
      'Clear all in-memory logs and request records.',
    )) {
      return {'ok': false, 'cancelled': true};
    }
    final container = globalState.container;
    container.read(logsProvider.notifier).value = FixedList(500);
    container.read(requestsProvider.notifier).value = FixedList(500);
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _getProfileYaml(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final profile = globalState.container
        .read(profilesProvider)
        .getProfile(profileId);
    if (profile == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    final path = await appPath.getProfilePath(profileId.toString());
    final file = File(path);
    if (!await file.exists()) {
      return {'ok': false, 'error': 'The profile file does not exist.'};
    }
    return {
      'ok': true,
      'profile_id': profileId,
      'label': profile.realLabel,
      'yaml': await file.readAsString(),
    };
  }

  Future<Map<String, dynamic>> _validateYaml(
    Map<String, dynamic> arguments,
  ) async {
    final content = _readString(arguments, 'yaml');
    final message = await coreController.validateConfigWithData(content);
    return {
      'ok': message.isEmpty,
      if (message.isNotEmpty) 'error': message,
    };
  }

  Future<Map<String, dynamic>> _createProfileYaml(
    Map<String, dynamic> arguments,
  ) async {
    final label = _readString(arguments, 'label');
    final content = _readString(arguments, 'yaml');
    final validation = await _validateYaml({'yaml': content});
    if (validation['ok'] != true) {
      return validation;
    }
    final approved = await confirm(
      'create_profile_yaml',
      '$label\n${content.length} bytes',
    );
    if (!approved) {
      return {'ok': false, 'cancelled': true};
    }
    final profile = await Profile.normal(
      label: label,
    ).saveFile(Uint8List.fromList(utf8.encode(content)));
    globalState.container
        .read(profilesActionProvider.notifier)
        .putProfile(profile);
    return {'ok': true, 'profile_id': profile.id, 'label': profile.realLabel};
  }

  Future<Map<String, dynamic>> _replaceProfileYaml(
    Map<String, dynamic> arguments,
  ) async {
    final profileId = _readInt(arguments, 'profile_id');
    final content = _readString(arguments, 'yaml');
    final container = globalState.container;
    final profile = container.read(profilesProvider).getProfile(profileId);
    if (profile == null) {
      return {'ok': false, 'error': 'Profile $profileId was not found.'};
    }
    final validation = await _validateYaml({'yaml': content});
    if (validation['ok'] != true) {
      return validation;
    }
    final approved = await confirm(
      'replace_profile_yaml',
      '${profile.realLabel}\n${content.length} bytes',
    );
    if (!approved) {
      return {'ok': false, 'cancelled': true};
    }
    final updated = await profile.saveFile(
      Uint8List.fromList(utf8.encode(content)),
    );
    container.read(profilesActionProvider.notifier).putProfile(updated);
    if (profileId == container.read(currentProfileIdProvider) ||
        profileId == container.read(globalOverwriteProfileIdProvider)) {
      await container
          .read(setupActionProvider.notifier)
          .applyProfile(force: true);
    }
    return {'ok': true, 'profile_id': profileId, 'label': profile.realLabel};
  }

  Future<Map<String, dynamic>> _updateSettings(
    Map<String, dynamic> arguments,
  ) async {
    if (arguments.isEmpty) {
      return {'ok': false, 'error': 'No settings were provided.'};
    }
    final container = globalState.container;
    final tunValue = arguments['tun'] as bool?;
    final systemProxyValue = arguments['system_proxy'] as bool?;
    final currentTun = container.read(patchClashConfigProvider).tun.enable;
    final currentSystemProxy = container
        .read(networkSettingProvider)
        .systemProxy;
    if ((tunValue != null && tunValue != currentTun) ||
        (systemProxyValue != null &&
            systemProxyValue != currentSystemProxy)) {
      final approved = await confirm(
        'update_settings',
        const JsonEncoder.withIndent('  ').convert(arguments),
      );
      if (!approved) {
        return {'ok': false, 'cancelled': true};
      }
    }

    container.read(patchClashConfigProvider.notifier).update((state) {
      var next = state;
      final modeName = arguments['mode'] as String?;
      if (modeName != null) {
        next = next.copyWith(mode: Mode.values.byName(modeName));
      }
      if (arguments['tun'] case final bool value) {
        next = next.copyWith(tun: next.tun.copyWith(enable: value));
      }
      if (arguments['allow_lan'] case final bool value) {
        next = next.copyWith(allowLan: value);
      }
      if (arguments['ipv6'] case final bool value) {
        next = next.copyWith(ipv6: value);
      }
      if (arguments['mixed_port'] case final num value) {
        final port = value.toInt();
        if (port < 1 || port > 65535) {
          throw const FormatException('mixed_port must be between 1 and 65535.');
        }
        next = next.copyWith(mixedPort: port);
      }
      if (arguments.containsKey('global_user_agent')) {
        final value = arguments['global_user_agent']?.toString().trim() ?? '';
        next = next.copyWith(globalUa: value.isEmpty ? null : value);
      }
      var dns = next.dns;
      if (arguments['dns_enabled'] case final bool value) {
        dns = dns.copyWith(enable: value);
      }
      if (arguments['dns_nameservers'] case final List value) {
        final nameservers = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
        if (nameservers.isEmpty) {
          throw const FormatException('dns_nameservers cannot be empty.');
        }
        dns = dns.copyWith(nameserver: nameservers);
      }
      return next.copyWith(dns: dns);
    });
    if (systemProxyValue != null) {
      container
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith(systemProxy: systemProxyValue));
    }
    container.read(appSettingProvider.notifier).update((state) {
      return state.copyWith(
        autoLaunch: arguments['auto_launch'] as bool? ?? state.autoLaunch,
        silentLaunch:
            arguments['silent_launch'] as bool? ?? state.silentLaunch,
        autoRun: arguments['auto_run'] as bool? ?? state.autoRun,
        autoCheckUpdate:
            arguments['auto_check_update'] as bool? ?? state.autoCheckUpdate,
        openLogs: arguments['open_logs'] as bool? ?? state.openLogs,
        closeConnections:
            arguments['close_connections'] as bool? ?? state.closeConnections,
        isAnimateToPage:
            arguments['animate_navigation'] as bool? ??
            state.isAnimateToPage,
      );
    });
    if (arguments['theme_mode'] case final String value) {
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith(themeMode: ThemeMode.values.byName(value)),
          );
    }
    if (arguments.containsKey('global_user_agent')) {
      final value = arguments['global_user_agent']?.toString().trim() ?? '';
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(customUserAgent: value));
    }
    await container
        .read(setupActionProvider.notifier)
        .applyProfile(force: true);
    return {'ok': true, 'settings': _getAppState()};
  }

  int _readInt(Map<String, dynamic> arguments, String key) {
    final value = arguments[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final result = int.tryParse(value?.toString() ?? '');
    if (result == null) {
      throw FormatException('$key must be an integer.');
    }
    return result;
  }

  String _readString(Map<String, dynamic> arguments, String key) {
    final value = arguments[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('$key cannot be empty.');
    }
    return value;
  }
}
