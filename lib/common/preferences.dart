import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class Preferences {
  static Preferences? _instance;
  static const _globalOverwriteProfileIdKey = 'globalOverwriteProfileId';
  static const _profileUserAgentsKey = 'profileUserAgents';
  static const _aiConfigKey = 'aiConfig';
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();
  int? _globalOverwriteProfileId;
  Map<int, String> _profileUserAgents = const {};
  AiConfig _aiConfig = const AiConfig();

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
        for (final entry in values.entries)
          entry.key.toString(): entry.value,
      }),
    );
  }

  AiConfig get aiConfig => _aiConfig;

  Future<void> loadAiConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    try {
      final rawValue = preferences?.getString(_aiConfigKey);
      _aiConfig = rawValue == null
          ? const AiConfig()
          : AiConfig.fromJson(
              Map<String, dynamic>.from(json.decode(rawValue) as Map),
            );
    } catch (_) {
      _aiConfig = const AiConfig();
    }
  }

  Future<void> setAiConfig(AiConfig value) async {
    _aiConfig = value;
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString(_aiConfigKey, json.encode(value.toJson()));
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
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
