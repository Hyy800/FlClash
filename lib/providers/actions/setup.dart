part of '../action.dart';

enum _SetupTaskResult { completed, handoffToCoreRestart }

class _RunRequest {
  final bool running;
  final bool initialize;

  const _RunRequest({required this.running, required this.initialize});
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  Timer? _runtimeTimer;
  Future<void>? _trafficUpdateOperation;
  final _setupScheduler = SerialTaskScheduler();
  final _listenerScheduler = SerialTaskScheduler();
  _RunRequest? _latestRunRequest;
  DateTime? _startTime;

  bool get _isRunning => _startTime != null && _startTime!.isBeforeNow;

  @override
  void build() {}

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(selectedMap: selectedMap, testUrl: testUrl);
  }

  void fullSetup() {
    if (!ref.read(initProvider)) return;
    ref.read(delayDataSourceProvider.notifier).value = {};
    unawaited(_runSetup(force: true));
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
    ref
        .read(ruleUsagesProvider.notifier)
        .sample(ref.read(globalRulesProvider), const []);
  }

  void _setLocalRunning(bool running) {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
    if (!running) {
      _startTime = null;
      debouncer.cancel(FunctionTag.applyProfile);
      _updateRunTime();
      return;
    }

    _startTime ??= DateTime.now();
    _refreshRunningState();
    _runtimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRunningState(),
    );
  }

  void _refreshRunningState() {
    _updateRunTime();
    if (_trafficUpdateOperation != null) {
      return;
    }
    final operation = ref.read(commonActionProvider.notifier).updateTraffic();
    _trafficUpdateOperation = operation;
    unawaited(_completeTrafficUpdate(operation));
  }

  Future<void> _completeTrafficUpdate(Future<void> operation) async {
    try {
      await operation;
    } finally {
      if (identical(_trafficUpdateOperation, operation)) {
        _trafficUpdateOperation = null;
      }
    }
  }

  void _updateRunTime() {
    final startTime = _startTime;
    ref.read(runTimeProvider.notifier).value = startTime == null
        ? null
        : DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
  }

  Future<void> _updateStartTime() async {
    _startTime = await service?.getRunTime();
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    if (system.isAndroid) {
      await _updateStartTime();
    }
    final shouldRun = _isRunning || ref.read(appSettingProvider).autoRun;
    if (shouldRun) {
      await setRunning(true, initialize: true);
    } else {
      await applyProfile(force: true);
    }
  }

  Future<void> setRunning(bool running, {bool initialize = false}) {
    if (running && !initialize && !ref.read(initProvider)) {
      return Future.value();
    }

    final request = _RunRequest(
      running: running,
      initialize: running && initialize,
    );
    _latestRunRequest = request;
    _setLocalRunning(running);
    if (request.initialize) {
      globalState.needInitStatus = false;
    }
    return running ? _start(request) : _stop(request);
  }

  Future<void> _start(_RunRequest request) async {
    if (request.initialize) {
      try {
        await applyProfile(
          force: true,
          preloadInvoke: () => _setCoreRunning(request),
        );
      } catch (_) {
        if (_isCurrent(request)) {
          await setRunning(false);
        }
      }
      return;
    }

    await _setCoreRunning(request);
    if (_isCurrent(request)) {
      applyProfileDebounce(force: true, silence: true);
    }
  }

  Future<void> _stop(_RunRequest request) async {
    await _setCoreRunning(request);
    if (!_isCurrent(request)) {
      return;
    }
    resetCoreTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    ref
        .read(ruleUsagesProvider.notifier)
        .sample(ref.read(globalRulesProvider), const []);
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<void> _setCoreRunning(_RunRequest request) {
    return _listenerScheduler.run(() async {
      if (!_isCurrent(request)) {
        return;
      }
      if (request.running && ref.read(suspendProvider)) {
        return;
      }
      await setCoreRunning(request.running);
    });
  }

  bool _isCurrent(_RunRequest request) => identical(_latestRunRequest, request);

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, updateConfig);
  }

  @protected
  Future<bool> setCoreRunning(bool running) {
    return running
        ? coreController.startListener()
        : coreController.stopListener();
  }

  @protected
  void resetCoreTraffic() {
    coreController.resetTraffic();
  }

  @visibleForTesting
  Future<void> updateConfig() async {
    await globalState.safeRun(() async {
      final updateParams = ref.read(updateParamsProvider);
      final shouldContinueSetup = await requestAdmin(updateParams.tun.enable);
      if (!shouldContinueSetup) {
        await _restartCoreAfterAuthorization();
        return;
      }
      final message = await coreController.updateConfig(
        updateParams.copyWith.tun(
          enable: _getEffectiveTunEnable(updateParams.tun.enable),
        ),
      );
      ref.read(checkIpNumProvider.notifier).add();
      if (message.isNotEmpty) throw message;
    });
  }

  void tryCheckIp() {
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) {
    return _runSetup(
      force: force,
      silence: silence,
      preloadInvoke: preloadInvoke,
    );
  }

  Future<void> applyRoutingRules({bool silence = false}) async {
    await applyProfile(force: true, silence: silence);
    await closeRoutingConnections();
    ref.read(ruleUsagesProvider.notifier).clear();
  }

  @protected
  Future<void> closeRoutingConnections() {
    return coreController.closeConnections();
  }

  Future<void> _runSetup({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _setupScheduler.run(() {
      return _setupConfig(
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        onUpdated: () async {
          await ref.read(proxiesActionProvider.notifier).updateGroups();
          await ref.read(providersProvider.notifier).syncProviders();
        },
      );
    });
    if (result != _SetupTaskResult.handoffToCoreRestart) {
      return;
    }
    // Release the current serial task before restartCore reapplies the profile.
    await _restartCoreAfterAuthorization();
  }

  Future<void> _restartCoreAfterAuthorization() async {
    try {
      await ref.read(coreActionProvider.notifier).restartCore();
    } catch (_) {
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.none;
      rethrow;
    }
  }

  Future<VM2<String, String>> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) return const VM2('', '');
    final defaultUA = globalState.packageInfo.ua;
    final networkVM2 = ref.read(
      networkSettingProvider.select(
        (state) => VM2(state.appendSystemDns, state.routeMode),
      ),
    );
    final overrideDns = ref.read(overrideDnsProvider);
    final appendSystemDns = networkVM2.a;
    final routeMode = networkVM2.b;
    final activeProfilePath = await appPath.getProfilePath(
      profileId.toString(),
    );
    final activeValidationMessage = await coreController.validateConfig(
      activeProfilePath,
    );
    final activeProfileValid = activeValidationMessage.isEmpty;
    final Map<String, dynamic> configMap;
    if (activeProfileValid) {
      configMap = await coreController.getConfig(profileId);
    } else {
      commonPrint.log(
        'Use safe base for invalid active profile $profileId: '
        '$activeValidationMessage',
        logLevel: LogLevel.warning,
      );
      configMap = {
        'proxies': <dynamic>[],
        'proxy-groups': <dynamic>[],
        'proxy-providers': <String, dynamic>{},
        'rules': <String>['MATCH,DIRECT'],
      };
    }
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (activeProfileValid) {
      addedRules.addAll(setupState.addedRules);
    }
    if (activeProfileValid &&
        setupState.overwriteType == OverwriteType.script) {
      scriptContent = await setupState.script?.content;
    } else if (activeProfileValid &&
        setupState.overwriteType == OverwriteType.custom) {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final profileUserAgent = ref.read(profileUserAgentsProvider)[profileId];
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
      globalUa: profileUserAgent?.isNotEmpty == true
          ? profileUserAgent
          : patchConfig.globalUa,
    );
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    var finalConfig = await makeRealProfileMapTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
      ),
    );
    final activeOnlyConfig = Map<String, dynamic>.from(
      json.decode(json.encode(finalConfig)) as Map,
    );
    final globalSources = <GlobalProfileSource>[];
    final disabledProfileIds = ref.read(disabledProfileIdsProvider);
    for (final profile in ref.read(profilesProvider)) {
      if (profile.id == profileId) continue;
      if (disabledProfileIds.contains(profile.id)) continue;
      try {
        final profilePath = await appPath.getProfilePath(profile.id.toString());
        final validationMessage = await coreController.validateConfig(
          profilePath,
        );
        if (validationMessage.isNotEmpty) {
          commonPrint.log(
            'Skip invalid global node source ${profile.id}: '
            '$validationMessage',
            logLevel: LogLevel.warning,
          );
          continue;
        }
        final source = await isolateGlobalProfileSource(
          GlobalProfileSource(
            profileId: profile.id,
            label: profile.realLabel,
            config: await coreController.getConfig(profile.id),
          ),
          profilesPath: directory,
        );
        globalSources.add(source);
      } catch (error) {
        commonPrint.log(
          'Skip global node source ${profile.id}: $error',
          logLevel: LogLevel.warning,
        );
      }
    }
    final safeGlobalNodePool = await buildValidatedGlobalNodePool(
      activeConfig: finalConfig,
      sources: globalSources,
      profilesPath: directory,
      validate: (candidate) async {
        try {
          final content = await encodeYamlTask(candidate);
          return (await coreController.validateConfigWithData(content)).isEmpty;
        } catch (_) {
          return false;
        }
      },
    );
    for (final skippedProfileId in safeGlobalNodePool.skippedProfileIds) {
      commonPrint.log(
        'Skip invalid global node source $skippedProfileId',
        logLevel: LogLevel.warning,
      );
    }
    final globalNodePool = safeGlobalNodePool.result;
    finalConfig = globalNodePool.config;
    final enabledGlobalRules = setupState.globalRules
        .where((rule) => rule.enabled)
        .toList();
    if (enabledGlobalRules.isNotEmpty) {
      final providerTargets = await loadProxyProviderTargets(
        finalConfig,
        profilesPath: directory,
      );
      final targetAliases = <String, List<String>>{
        for (final entry in globalNodePool.targetAliases.entries)
          entry.key: [...entry.value],
      };
      for (final target in providerTargets) {
        final namespaceEnd = target.indexOf('] ');
        if (!target.startsWith('[') || namespaceEnd < 0) continue;
        final original = target.substring(namespaceEnd + 2);
        final aliases = targetAliases.putIfAbsent(original, () => <String>[]);
        if (!aliases.contains(target)) aliases.add(target);
      }
      final script = buildRulesOverrideScript(
        enabledRuleValues(enabledGlobalRules),
        additionalTargets: {...providerTargets, ...globalNodePool.targets},
        targetAliases: targetAliases,
      );
      finalConfig = await handleEvaluate(script, finalConfig);
    }
    var content = await encodeYamlTask(finalConfig);
    final finalValidationMessage = await coreController.validateConfigWithData(
      content,
    );
    if (finalValidationMessage.isNotEmpty) {
      commonPrint.log(
        'Global node pool rejected, use isolated active profile: '
        '$finalValidationMessage',
        logLevel: LogLevel.warning,
      );
      finalConfig = activeOnlyConfig;
      if (enabledGlobalRules.isNotEmpty) {
        final providerTargets = await loadProxyProviderTargets(
          finalConfig,
          profilesPath: directory,
        );
        final script = buildRulesOverrideScript(
          enabledRuleValues(enabledGlobalRules),
          additionalTargets: providerTargets,
        );
        finalConfig = await handleEvaluate(script, finalConfig);
      }
      content = await encodeYamlTask(finalConfig);
      final activeValidationMessage = await coreController
          .validateConfigWithData(content);
      if (activeValidationMessage.isNotEmpty) {
        throw activeValidationMessage;
      }
    }
    return VM2(content, content.toMd5());
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.a;
    } catch (e) {
      globalState.showNotifier(e.toString());
    }
    return '';
  }

  bool _getEffectiveTunEnable(bool enableTun) {
    final authorizationState = ref.read(authorizedTunEnableProvider);
    return enableTun && authorizationState == TunAuthorizationState.authorized;
  }

  @protected
  Future<AuthorizeCode> authorizeCore() {
    return system.authorizeCore();
  }

  @visibleForTesting
  Future<bool> requestAdmin(bool enableTun) async {
    if (!enableTun) {
      return true;
    }
    final authorizationState = ref.read(authorizedTunEnableProvider);
    if (authorizationState != TunAuthorizationState.none) {
      return true;
    }

    final authorizationNotifier = ref.read(
      authorizedTunEnableProvider.notifier,
    );
    authorizationNotifier.value = TunAuthorizationState.unauthorized;

    final code = await authorizeCore();

    switch (code) {
      case AuthorizeCode.success:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return false;
      case AuthorizeCode.none:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return true;
      case AuthorizeCode.error:
        return true;
    }
  }

  Future<_SetupTaskResult> _setupConfig({
    bool force = false,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.realLabel}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final shouldContinueSetup = await requestAdmin(patchConfig.tun.enable);
    if (!shouldContinueSetup) {
      return _SetupTaskResult.handoffToCoreRestart;
    }
    final effectiveTunEnable = _getEffectiveTunEnable(patchConfig.tun.enable);
    final realPatchConfig = patchConfig.copyWith.tun(
      enable: effectiveTunEnable,
    );
    final setupState = await ref.read(setupStateProvider(profile?.id).future);
    final vm2 = await getProfile(
      setupState: setupState,
      patchConfig: realPatchConfig,
    );
    final yamlString = vm2.a;
    final yamlMd5 = vm2.b;
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) {
      return _SetupTaskResult.completed;
    }
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      await preferences.saveShareState(sharedState);
    }
    await globalState.loadingRun(
      () async {
        final configFilePath = await appPath.configFilePath;
        await File(configFilePath).safeWriteAsString(yamlString);
        final message = await coreController.setupConfig(
          params: _setupParams,
          preloadInvoke: preloadInvoke,
        );
        if (message.isNotEmpty && !message.endsWith('is empty')) {
          throw message;
        }
        globalState.lastConfigMd5 = yamlMd5;
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    return _SetupTaskResult.completed;
  }
}
