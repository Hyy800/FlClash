import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:collection/collection.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/config.g.dart';

@riverpod
class AppSetting extends _$AppSetting with AutoDisposeNotifierMixin {
  @override
  AppSettingProps build() {
    return const AppSettingProps();
  }
}

@Riverpod(keepAlive: true)
class WindowSetting extends _$WindowSetting with AutoDisposeNotifierMixin {
  @override
  WindowProps build() {
    return const WindowProps();
  }

  void hello() {}
}

@riverpod
class VpnSetting extends _$VpnSetting with AutoDisposeNotifierMixin {
  @override
  VpnProps build() {
    return const VpnProps();
  }
}

@riverpod
class NetworkSetting extends _$NetworkSetting with AutoDisposeNotifierMixin {
  @override
  NetworkProps build() {
    return const NetworkProps();
  }
}

@riverpod
class ThemeSetting extends _$ThemeSetting with AutoDisposeNotifierMixin {
  @override
  ThemeProps build() {
    return const ThemeProps();
  }
}

@riverpod
class CurrentProfileId extends _$CurrentProfileId
    with AutoDisposeNotifierMixin {
  @override
  int? build() {
    return null;
  }
}

final globalOverwriteProfileIdProvider =
    NotifierProvider<GlobalOverwriteProfileId, int?>(
      GlobalOverwriteProfileId.new,
    );

class GlobalOverwriteProfileId extends Notifier<int?> {
  @override
  int? build() => preferences.globalOverwriteProfileId;

  Future<void> setValue(int? value) async {
    if (state == value) {
      return;
    }
    state = value;
    await preferences.setGlobalOverwriteProfileId(value);
  }
}

final profileUserAgentsProvider =
    NotifierProvider<ProfileUserAgents, Map<int, String>>(
      ProfileUserAgents.new,
    );

class ProfileUserAgents extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() => preferences.profileUserAgents;

  Future<void> setUserAgent(int profileId, String userAgent) async {
    final next = Map<int, String>.from(state);
    final value = userAgent.trim();
    if (value.isEmpty) {
      next.remove(profileId);
    } else {
      next[profileId] = value;
    }
    if (const MapEquality<int, String>().equals(next, state)) {
      return;
    }
    state = Map.unmodifiable(next);
    await preferences.setProfileUserAgents(state);
  }

  Future<void> remove(int profileId) async {
    if (!state.containsKey(profileId)) {
      return;
    }
    final next = Map<int, String>.from(state)..remove(profileId);
    state = Map.unmodifiable(next);
    await preferences.setProfileUserAgents(state);
  }
}

final userAgentPresetsProvider =
    NotifierProvider<UserAgentPresets, List<UserAgentPreset>>(
      UserAgentPresets.new,
    );

class UserAgentPresets extends Notifier<List<UserAgentPreset>> {
  @override
  List<UserAgentPreset> build() => preferences.userAgentPresets;

  Future<void> save({
    String? id,
    required String name,
    required String value,
  }) async {
    final normalizedName = name.trim();
    final normalizedValue = value.trim();
    if (normalizedName.isEmpty || normalizedValue.isEmpty) {
      return;
    }
    final preset = UserAgentPreset(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: normalizedName,
      value: normalizedValue,
    );
    final index = state.indexWhere((item) => item.id == preset.id);
    final next = [...state];
    if (index == -1) {
      next.add(preset);
    } else {
      next[index] = preset;
    }
    state = List.unmodifiable(next);
    await preferences.setUserAgentPresets(state);
  }

  Future<void> remove(String id) async {
    final next = state.where((item) => item.id != id).toList();
    if (next.length == state.length) return;
    state = List.unmodifiable(next);
    await preferences.setUserAgentPresets(state);
  }
}

final aiSettingProvider = NotifierProvider<AiSetting, AiConfig>(AiSetting.new);

class AiSetting extends Notifier<AiConfig> {
  @override
  AiConfig build() => preferences.aiConfig;

  Future<void> save(AiConfig value) async {
    state = value;
    await preferences.setAiConfig(value);
  }
}

final aiSkillsProvider = NotifierProvider<AiSkills, List<AiSkill>>(
  AiSkills.new,
);

class AiSkills extends Notifier<List<AiSkill>> {
  @override
  List<AiSkill> build() => preferences.aiSkills;

  Future<AiSkill> importSkill({
    required String name,
    required String content,
  }) async {
    final normalizedName = name.trim();
    final existing = state
        .where(
          (skill) => skill.name.toLowerCase() == normalizedName.toLowerCase(),
        )
        .firstOrNull;
    final skill = existing == null
        ? AiSkill(name: normalizedName, content: content.trim())
        : existing.copyWith(
            name: normalizedName,
            content: content.trim(),
            enabled: true,
          );
    final next = [
      skill,
      for (final item in state)
        if (item.id != skill.id) item,
    ];
    state = List.unmodifiable(next);
    await preferences.setAiSkills(state);
    return skill;
  }

  Future<void> setEnabled(String id, bool enabled) async {
    state = [
      for (final skill in state)
        skill.id == id ? skill.copyWith(enabled: enabled) : skill,
    ];
    await preferences.setAiSkills(state);
  }

  Future<void> deleteSkill(String id) async {
    state = state.where((skill) => skill.id != id).toList();
    await preferences.setAiSkills(state);
  }
}

final aiSessionsProvider = NotifierProvider<AiSessions, AiSessionStore>(
  AiSessions.new,
);

class AiSessions extends Notifier<AiSessionStore> {
  @override
  AiSessionStore build() => preferences.aiSessionStore;

  Future<void> _save(AiSessionStore value) async {
    state = value;
    await preferences.setAiSessions(value);
  }

  Future<String> createSession() async {
    if (state.canReuseActiveSession) return state.activeSessionId;
    final session = AiSession();
    await _save(
      AiSessionStore(
        activeSessionId: session.id,
        sessions: [session, ...state.sessions],
      ),
    );
    return session.id;
  }

  Future<void> selectSession(String id) async {
    if (id == state.activeSessionId ||
        !state.sessions.any((session) => session.id == id)) {
      return;
    }
    await _save(AiSessionStore(activeSessionId: id, sessions: state.sessions));
  }

  Future<void> renameSession(String id, String title) async {
    final value = title.trim();
    if (value.isEmpty) return;
    await _save(
      AiSessionStore(
        activeSessionId: state.activeSessionId,
        sessions: [
          for (final session in state.sessions)
            session.id == id ? session.copyWith(title: value) : session,
        ],
      ),
    );
  }

  Future<void> deleteSession(String id) async {
    final sessions = state.sessions
        .where((session) => session.id != id)
        .toList();
    if (sessions.isEmpty) {
      final session = AiSession();
      await _save(
        AiSessionStore(activeSessionId: session.id, sessions: [session]),
      );
      return;
    }
    await _save(
      AiSessionStore(
        activeSessionId: state.activeSessionId == id
            ? sessions.first.id
            : state.activeSessionId,
        sessions: sessions,
      ),
    );
  }

  Future<void> addMessage(String sessionId, AiChatMessage message) async {
    final session = state.sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    if (session == null) return;
    final shouldName = session.messages.isEmpty && message.role == 'user';
    final title = shouldName
        ? (message.content.trim().isEmpty && message.attachments.isNotEmpty
                  ? message.attachments.first.name
                  : message.content)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
        : session.title;
    await replaceSession(
      session.copyWith(
        title: title.length > 28 ? '${title.substring(0, 28)}…' : title,
        messages: [...session.messages, message],
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> replaceMessages(
    String sessionId,
    List<AiChatMessage> messages,
  ) async {
    final session = state.sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    if (session == null) return;
    await replaceSession(
      session.copyWith(messages: messages, updatedAt: DateTime.now()),
    );
  }

  Future<void> replaceSession(AiSession session) async {
    await _save(
      AiSessionStore(
        activeSessionId: state.activeSessionId,
        sessions: [
          session,
          for (final item in state.sessions)
            if (item.id != session.id) item,
        ],
      ),
    );
  }
}

@riverpod
class DavSetting extends _$DavSetting with AutoDisposeNotifierMixin {
  @override
  DAVProps? build() {
    return null;
  }
}

@riverpod
class OverrideDns extends _$OverrideDns with AutoDisposeNotifierMixin {
  @override
  bool build() {
    return false;
  }
}

@riverpod
class HotKeyActions extends _$HotKeyActions with AutoDisposeNotifierMixin {
  @override
  List<HotKeyAction> build() {
    return [];
  }
}

@riverpod
class ProxiesStyleSetting extends _$ProxiesStyleSetting
    with AutoDisposeNotifierMixin {
  @override
  ProxiesStyleProps build() {
    return const ProxiesStyleProps();
  }
}

@Riverpod(name: 'patchClashConfigProvider')
class _PatchClashConfig extends _$PatchClashConfig
    with AutoDisposeNotifierMixin {
  @override
  PatchClashConfig build() {
    return const PatchClashConfig();
  }
}

@riverpod
class ExcludeSSIDs extends _$ExcludeSSIDs with AutoDisposeNotifierMixin {
  @override
  List<String> build() {
    return [];
  }
}

@Riverpod(name: 'configProvider')
Config _config(Ref ref) {
  final appSettingProps = ref.watch(appSettingProvider);
  final windowProps = ref.watch(windowSettingProvider);
  final vpnProps = ref.watch(vpnSettingProvider);
  final networkProps = ref.watch(networkSettingProvider);
  final themeProps = ref.watch(themeSettingProvider);
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final davProps = ref.watch(davSettingProvider);
  final overrideDns = ref.watch(overrideDnsProvider);
  final hotKeyActions = ref.watch(hotKeyActionsProvider);
  final proxiesStyleProps = ref.watch(proxiesStyleSettingProvider);
  final patchClashConfig = ref.watch(patchClashConfigProvider);
  final excludeSSIDs = ref.watch(excludeSSIDsProvider);
  return Config(
    appSettingProps: appSettingProps,
    windowProps: windowProps,
    vpnProps: vpnProps,
    networkProps: networkProps,
    themeProps: themeProps,
    currentProfileId: currentProfileId,
    davProps: davProps,
    overrideDns: overrideDns,
    hotKeyActions: hotKeyActions,
    proxiesStyleProps: proxiesStyleProps,
    patchClashConfig: patchClashConfig,
    excludeSSIDs: excludeSSIDs,
  );
}

List<Override> buildConfigOverrides(Config config) {
  return [
    appSettingProvider.overrideWithBuild((_, _) => config.appSettingProps),
    windowSettingProvider.overrideWithBuild((_, _) => config.windowProps),
    vpnSettingProvider.overrideWithBuild((_, _) => config.vpnProps),
    networkSettingProvider.overrideWithBuild((_, _) => config.networkProps),
    themeSettingProvider.overrideWithBuild((_, _) => config.themeProps),
    currentProfileIdProvider.overrideWithBuild(
      (_, _) => config.currentProfileId,
    ),
    davSettingProvider.overrideWithBuild((_, _) => config.davProps),
    overrideDnsProvider.overrideWithBuild((_, _) => config.overrideDns),
    hotKeyActionsProvider.overrideWithBuild((_, _) => config.hotKeyActions),
    proxiesStyleSettingProvider.overrideWithBuild(
      (_, _) => config.proxiesStyleProps,
    ),
    patchClashConfigProvider.overrideWithBuild(
      (_, _) => config.patchClashConfig,
    ),
    excludeSSIDsProvider.overrideWithBuild((_, _) => config.excludeSSIDs),
  ];
}
