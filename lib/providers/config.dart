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

final aiSettingProvider = NotifierProvider<AiSetting, AiConfig>(AiSetting.new);

class AiSetting extends Notifier<AiConfig> {
  @override
  AiConfig build() => preferences.aiConfig;

  Future<void> save(AiConfig value) async {
    state = value;
    await preferences.setAiConfig(value);
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
