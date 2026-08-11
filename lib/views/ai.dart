import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ai/ai_service.dart';
import 'package:fl_clash/features/ai/ai_tools.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiView extends ConsumerStatefulWidget {
  const AiView({super.key});

  @override
  ConsumerState<AiView> createState() => _AiViewState();
}

class _AiViewState extends ConsumerState<AiView> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = AiApiService();
  List<String> _models = const [];
  AiApiProtocol _protocol = AiApiProtocol.auto;
  String _streamedText = '';
  String _pendingDelta = '';
  bool _frameScheduled = false;
  bool _busy = false;
  bool _hideKey = true;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiSettingProvider);
    _baseUrlController.text = config.baseUrl;
    _apiKeyController.text = config.apiKey;
    _modelController.text = config.model;
    _models = config.cachedModels;
    _protocol = config.protocol;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  AiConfig _draftConfig({bool requireModel = true}) {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Invalid API URL.');
    }
    if (apiKey.isEmpty) {
      throw const FormatException('API Key cannot be empty.');
    }
    if (requireModel && model.isEmpty) {
      throw const FormatException('Model cannot be empty.');
    }
    return AiConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      protocol: _protocol,
      cachedModels: _models,
    );
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await action();
    } catch (error, stackTrace) {
      commonPrint.log(
        'AI request failed: $error, $stackTrace',
        logLevel: LogLevel.warning,
      );
      globalState.showNotifier(error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchModels() async {
    final models = await _run(() => _service.fetchModels(_draftConfig(requireModel: false)));
    if (!mounted || models == null) return;
    if (models.isEmpty) {
      globalState.showNotifier('The API returned no models.');
      return;
    }
    setState(() {
      _models = models;
      if (!models.contains(_modelController.text.trim())) {
        _modelController.text = models.first;
      }
    });
    await ref.read(aiSettingProvider.notifier).save(_draftConfig());
    if (mounted) await _showModelPicker();
  }

  Future<void> _showModelPicker() async {
    if (_models.isEmpty) return;
    final searchController = TextEditingController();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = _models
                .where((model) => model.toLowerCase().contains(query))
                .toList();
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Model')),
                  Text(
                    '${filtered.length}/${_models.length}',
                    style: context.textTheme.labelMedium,
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 440,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.appLocalizations.search,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final model = filtered[index];
                          final selected = model == _modelController.text.trim();
                          return ListTile(
                            selected: selected,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.memory_rounded,
                            ),
                            title: Text(model, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.pop(dialogContext, model),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.appLocalizations.cancel),
                ),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();
    if (selected != null && mounted) {
      setState(() => _modelController.text = selected);
    }
  }

  Future<void> _saveConfig() async {
    try {
      await ref.read(aiSettingProvider.notifier).save(_draftConfig());
      if (!mounted) return;
      globalState.showNotifier(context.appLocalizations.save);
    } catch (error) {
      globalState.showNotifier(error.toString());
    }
  }

  Future<void> _testModel() async {
    final result = await _run(() async {
      await _service.testModel(_draftConfig());
      return true;
    });
    if (result == true && mounted) {
      globalState.showNotifier(context.appLocalizations.connected);
    }
  }

  Future<bool> _confirmTool(String action, String details) async {
    return await globalState.showMessage(
          context: context,
          title: 'AI · $action',
          message: TextSpan(text: details),
        ) ==
        true;
  }

  void _appendDelta(String delta) {
    if (!mounted || delta.isEmpty) return;
    _pendingDelta += delta;
    if (_frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted || _pendingDelta.isEmpty) return;
      setState(() {
        _streamedText += _pendingDelta;
        _pendingDelta = '';
      });
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _busy) return;
    AiConfig config;
    try {
      config = _draftConfig();
    } catch (error) {
      globalState.showNotifier(error.toString());
      return;
    }
    final sessionId = ref.read(aiSessionsProvider).activeSessionId;
    _messageController.clear();
    await ref
        .read(aiSessionsProvider.notifier)
        .addMessage(sessionId, AiChatMessage(role: 'user', content: content));
    setState(() {
      _streamedText = '';
      _pendingDelta = '';
    });
    _scrollToBottom();
    final reply = await _run(() async {
      var session = ref
          .read(aiSessionsProvider)
          .sessions
          .firstWhere((item) => item.id == sessionId);
      session = await const AiContextCompressor().compress(
        session,
        config,
        _service,
      );
      await ref.read(aiSessionsProvider.notifier).replaceSession(session);
      final executor = AiToolExecutor(confirm: _confirmTool);
      return AiAgent(_service).run(
        config: config,
        history: session.messages,
        summary: session.summary,
        toolHandler: executor.execute,
        onDelta: _appendDelta,
      );
    });
    if (!mounted || reply == null || reply.trim().isEmpty) {
      if (mounted) setState(() => _streamedText = '');
      return;
    }
    await ref
        .read(aiSessionsProvider.notifier)
        .addMessage(sessionId, AiChatMessage(role: 'assistant', content: reply));
    if (mounted) setState(() => _streamedText = '');
    _scrollToBottom();
  }

  Future<void> _createSession() async {
    if (_busy) return;
    await ref.read(aiSessionsProvider.notifier).createSession();
    _scrollToBottom();
  }

  Future<void> _renameSession(AiSession session) async {
    final controller = TextEditingController(text: session.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.appLocalizations.rename),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.appLocalizations.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref.read(aiSessionsProvider.notifier).renameSession(session.id, value);
    }
  }

  Future<void> _deleteSession(AiSession session) async {
    final approved = await globalState.showMessage(
      context: context,
      title: context.appLocalizations.delete,
      message: TextSpan(text: session.title),
    );
    if (approved == true) {
      await ref.read(aiSessionsProvider.notifier).deleteSession(session.id);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildSettings() {
    final l10n = context.appLocalizations;
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: context.colorScheme.primary),
                const SizedBox(width: 10),
                Text('AI', style: context.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'API ${l10n.url}',
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: _hideKey,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'API ${l10n.key}',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  tooltip: 'API Key',
                  onPressed: () => setState(() => _hideKey = !_hideKey),
                  icon: Icon(
                    _hideKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AiApiProtocol>(
              initialValue: _protocol,
              decoration: const InputDecoration(
                labelText: 'Protocol',
                prefixIcon: Icon(Icons.hub_outlined),
              ),
              items: AiApiProtocol.values
                  .map((item) => DropdownMenuItem(value: item, child: Text(item.label)))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _protocol = value ?? _protocol),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: 'Model',
                prefixIcon: const Icon(Icons.memory_rounded),
                suffixIcon: _models.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.search,
                        onPressed: _busy ? null : _showModelPicker,
                        icon: const Icon(Icons.unfold_more_rounded),
                      ),
              ),
              onTap: _models.isEmpty || _busy ? null : _showModelPicker,
            ),
            if (_models.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${_models.length} Models',
                style: context.textTheme.labelSmall,
                textAlign: TextAlign.end,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _fetchModels,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Models'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _testModel,
                  icon: const Icon(Icons.network_check_rounded),
                  label: Text(l10n.connected),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _saveConfig,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHeader(AiSessionStore store) {
    final session = store.activeSession;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<String>(
              enabled: !_busy,
              tooltip: context.appLocalizations.more,
              onSelected: (id) => ref.read(aiSessionsProvider.notifier).selectSession(id),
              itemBuilder: (_) => store.sessions
                  .map(
                    (item) => PopupMenuItem(
                      value: item.id,
                      child: Row(
                        children: [
                          Icon(
                            item.id == session.id
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item.title, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      session.title,
                      style: context.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: context.appLocalizations.add,
            onPressed: _busy ? null : _createSession,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'rename') _renameSession(session);
              if (value == 'delete') _deleteSession(session);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(context.appLocalizations.rename),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.appLocalizations.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(AiSessionStore store) {
    final messages = store.activeSession.messages;
    final visibleMessages = [
      ...messages,
      if (_streamedText.isNotEmpty)
        AiChatMessage(role: 'assistant', content: _streamedText),
    ];
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          _buildSessionHeader(store),
          Divider(height: 1, color: context.colorScheme.outlineVariant),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: visibleMessages.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 52,
                        color: context.colorScheme.primary.withAlpha(150),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey(store.activeSessionId),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(18),
                      itemCount: visibleMessages.length,
                      itemBuilder: (_, index) =>
                          _MessageBubble(message: visibleMessages[index]),
                    ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: !_busy
                ? const SizedBox.shrink(key: ValueKey(false))
                : const LinearProgressIndicator(key: ValueKey(true), minHeight: 2),
          ),
          Divider(height: 1, color: context.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: context.appLocalizations.messageTest,
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: context.appLocalizations.submit,
                  onPressed: _busy ? null : _sendMessage,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(aiSessionsProvider);
    return CommonScaffold(
      title: 'AI',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: LayoutBuilder(
          builder: (_, constraints) {
            if (constraints.maxWidth >= 820) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 330, child: _buildSettings()),
                  const SizedBox(width: 14),
                  Expanded(child: _buildConversation(sessions)),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: 360, child: _buildSettings()),
                const SizedBox(height: 12),
                Expanded(child: _buildConversation(sessions)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? context.colorScheme.primaryContainer
              : context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
        ),
        child: SelectableText(
          message.content,
          style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}
