import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/features/ai/ai_data_store.dart';
import 'package:fl_clash/features/overwrite/rule_traffic_store.dart';
import 'package:fl_clash/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class Preferences {
  static Preferences? _instance;
  static const _globalOverwriteProfileIdKey = 'globalOverwriteProfileId';
  static const _profileUserAgentsKey = 'profileUserAgents';
  static const _disabledProfileIdsKey = 'disabledProfileIds';
  static const _userAgentPresetsKey = 'userAgentPresets';
  static const _aiConfigKey = 'aiConfig';
  static const _aiSessionsKey = 'aiSessions';
  static const _aiSkillsKey = 'aiSkills';
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();
  int? _globalOverwriteProfileId;
  Map<int, String> _profileUserAgents = const {};
  Set<int> _disabledProfileIds = const {};
  List<UserAgentPreset> _userAgentPresets = const [];
  AiConfig _aiConfig = const AiConfig();
  AiSessionStore _aiSessionStore = AiSessionStore.initial();
  List<AiSkill> _aiSkills = const [];
  AiDataStore? _aiDataStore;
  Future<void> _aiWriteOperation = Future<void>.value();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, _) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<int> getVersion() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt('version') ?? 0;
  }

  Future<void> setVersion(int version) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt('version', version);
  }

  int? get globalOverwriteProfileId => _globalOverwriteProfileId;

  Future<void> loadGlobalOverwriteProfileId() async {
    final preferences = await sharedPreferencesCompleter.future;
    _globalOverwriteProfileId = int.tryParse(
      preferences?.getString(_globalOverwriteProfileIdKey) ?? '',
    );
  }

  Future<void> setGlobalOverwriteProfileId(int? profileId) async {
    _globalOverwriteProfileId = profileId;
    final preferences = await sharedPreferencesCompleter.future;
    if (profileId == null) {
      await preferences?.remove(_globalOverwriteProfileIdKey);
      return;
    }
    await preferences?.setString(
      _globalOverwriteProfileIdKey,
      profileId.toString(),
    );
  }

  Map<int, String> get profileUserAgents => _profileUserAgents;

  Future<void> loadProfileUserAgents() async {
    final preferences = await sharedPreferencesCompleter.future;
    try {
      final rawValue = preferences?.getString(_profileUserAgentsKey);
      final data = rawValue == null
          ? const <String, dynamic>{}
          : json.decode(rawValue) as Map<String, dynamic>;
      _profileUserAgents = {
        for (final entry in data.entries)
          if (int.tryParse(entry.key) != null && entry.value is String)
            int.parse(entry.key): entry.value as String,
      };
    } catch (_) {
      _profileUserAgents = const {};
    }
  }

  Future<void> setProfileUserAgents(Map<int, String> values) async {
    _profileUserAgents = Map.unmodifiable(values);
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString(
      _profileUserAgentsKey,
      json.encode({
        for (final entry in values.entries) entry.key.toString(): entry.value,
      }),
    );
  }

  Set<int> get disabledProfileIds => _disabledProfileIds;

  Future<void> loadDisabledProfileIds() async {
    final preferences = await sharedPreferencesCompleter.future;
    _disabledProfileIds =
        (preferences?.getStringList(_disabledProfileIdsKey) ?? [])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
  }

  Future<void> setDisabledProfileIds(Set<int> values) async {
    _disabledProfileIds = Set.unmodifiable(values);
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setStringList(
      _disabledProfileIdsKey,
      values.map((id) => id.toString()).toList(),
    );
  }

  List<UserAgentPreset> get userAgentPresets => _userAgentPresets;

  Future<void> loadUserAgentPresets() async {
    final preferences = await sharedPreferencesCompleter.future;
    try {
      final rawValue = preferences?.getString(_userAgentPresetsKey);
      final data = rawValue == null ? const [] : json.decode(rawValue) as List;
      _userAgentPresets = data
          .whereType<Map>()
          .map(
            (item) => UserAgentPreset.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (item) =>
                item.id.trim().isNotEmpty &&
                item.name.trim().isNotEmpty &&
                item.value.trim().isNotEmpty,
          )
          .toList();
    } catch (_) {
      _userAgentPresets = const [];
    }
  }

  Future<void> setUserAgentPresets(List<UserAgentPreset> values) async {
    _userAgentPresets = List.unmodifiable(values);
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString(
      _userAgentPresetsKey,
      json.encode(values.map((item) => item.toJson()).toList()),
    );
  }

  AiConfig get aiConfig => _aiConfig;

  Future<void> loadAiData(String path) async {
    final store = AiDataStore(File(path));
    _aiDataStore = store;
    final savedData = await store.read();
    if (savedData != null) {
      _applyAiData(savedData);
      await _removeLegacyAiData();
      return;
    }
    final preferences = await sharedPreferencesCompleter.future;
    final hasLegacyData =
        preferences?.containsKey(_aiConfigKey) == true ||
        preferences?.containsKey(_aiSessionsKey) == true ||
        preferences?.containsKey(_aiSkillsKey) == true;
    if (!hasLegacyData) return;
    _aiConfig = _readLegacyAiConfig(preferences?.getString(_aiConfigKey));
    _aiSessionStore = _readLegacyAiSessions(
      preferences?.getString(_aiSessionsKey),
    );
    _aiSkills = _readLegacyAiSkills(preferences?.getString(_aiSkillsKey));
    await _saveAiData();
    await _removeLegacyAiData();
  }

  Future<void> _removeLegacyAiData() async {
    final preferences = await sharedPreferencesCompleter.future;
    if (preferences == null) return;
    await preferences.remove(_aiConfigKey);
    await preferences.remove(_aiSessionsKey);
    await preferences.remove(_aiSkillsKey);
  }

  void _applyAiData(AiData data) {
    _aiConfig = data.config;
    _aiSessionStore = data.sessions;
    _aiSkills = List.unmodifiable(data.skills);
  }

  AiConfig _readLegacyAiConfig(String? rawValue) {
    try {
      return rawValue == null
          ? const AiConfig()
          : AiConfig.fromJson(
              Map<String, dynamic>.from(json.decode(rawValue) as Map),
            );
    } catch (_) {
      return const AiConfig();
    }
  }

  Future<void> setAiConfig(AiConfig value) async {
    _aiConfig = value;
    await _saveAiData();
  }

  AiSessionStore get aiSessionStore => _aiSessionStore;

  AiSessionStore _readLegacyAiSessions(String? rawValue) {
    try {
      return rawValue == null
          ? AiSessionStore.initial()
          : AiSessionStore.fromJson(
              Map<String, dynamic>.from(json.decode(rawValue) as Map),
            );
    } catch (_) {
      return AiSessionStore.initial();
    }
  }

  Future<void> setAiSessions(AiSessionStore value) async {
    _aiSessionStore = value;
    await _saveAiData();
  }

  List<AiSkill> get aiSkills => _aiSkills;

  List<AiSkill> _readLegacyAiSkills(String? rawValue) {
    try {
      final data = rawValue == null ? const [] : json.decode(rawValue) as List;
      return data
          .whereType<Map>()
          .map((item) => AiSkill.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setAiSkills(List<AiSkill> value) async {
    _aiSkills = List.unmodifiable(value);
    await _saveAiData();
  }

  Future<void> _saveAiData() {
    Future<void> write() async {
      final store = _aiDataStore;
      if (store == null) return;
      await store.write(
        AiData(config: _aiConfig, sessions: _aiSessionStore, skills: _aiSkills),
      );
    }

    final operation = _aiWriteOperation.catchError((_) {}).then((_) => write());
    _aiWriteOperation = operation;
    return operation;
  }

  Future<void> saveShareState(SharedState shareState) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString('sharedState', json.encode(shareState));
  }

  Future<Map<String, Object?>?> getConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final configString = preferences?.getString(configKey);
      if (configString == null) return null;
      final Map<String, Object?>? configMap = json.decode(configString);
      return configMap;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> getClashConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final clashConfigString = preferences?.getString(clashConfigKey);
      if (clashConfigString == null) return null;
      return json.decode(clashConfigString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearClashConfig() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      await preferences?.remove(clashConfigKey);
      return;
    } catch (_) {
      return;
    }
  }

  Future<Config?> getConfig() async {
    final configMap = await getConfigMap();
    if (configMap == null) {
      return null;
    }
    return Config.fromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.setString(configKey, json.encode(config)) ?? false;
  }

  Future<void> clearPreferences() async {
    await _aiWriteOperation.catchError((_) {});
    await _aiDataStore?.delete();
    await ruleTrafficStore.delete();
    _aiConfig = const AiConfig();
    _aiSessionStore = AiSessionStore.initial();
    _aiSkills = const [];
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
