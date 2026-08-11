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
  final List<AiChatMessage> _messages = [];
  List<String> _models = const [];
  String? _selectedModel;
  bool _busy = false;
  bool _hideKey = true;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiSettingProvider);
    _baseUrlController.text = config.baseUrl;
    _apiKeyController.text = config.apiKey;
    _modelController.text = config.model;
    _selectedModel = config.model.isEmpty ? null : config.model;
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
    final model = (_selectedModel ?? _modelController.text).trim();
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
    return AiConfig(baseUrl: baseUrl, apiKey: apiKey, model: model);
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    if (_busy) {
      return null;
    }
    setState(() {
      _busy = true;
    });
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
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _fetchModels() async {
    final models = await _run(() async {
      final config = _draftConfig(requireModel: false);
      return _service.fetchModels(config);
    });
    if (!mounted || models == null) {
      return;
    }
    if (models.isEmpty) {
      globalState.showNotifier('The API returned no models.');
      return;
    }
    final currentModel = _selectedModel ?? _modelController.text.trim();
    setState(() {
      _models = models;
      _selectedModel = models.contains(currentModel)
          ? currentModel
          : models.first;
      _modelController.text = _selectedModel!;
    });
  }

  Future<void> _saveConfig() async {
    try {
      final config = _draftConfig();
      await ref.read(aiSettingProvider.notifier).save(config);
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
    if (result != true || !mounted) {
      return;
    }
    globalState.showNotifier(context.appLocalizations.connected);
  }

  Future<bool> _confirmTool(String action, String details) async {
    final result = await globalState.showMessage(
      context: context,
      title: 'AI · $action',
      message: TextSpan(text: details),
    );
    return result == true;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _busy) {
      return;
    }
    AiConfig config;
    try {
      config = _draftConfig();
    } catch (error) {
      globalState.showNotifier(error.toString());
      return;
    }
    _messageController.clear();
    setState(() {
      _messages.add(AiChatMessage(role: 'user', content: content));
    });
    _scrollToBottom();
    final reply = await _run(() async {
      final history = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : List<AiChatMessage>.from(_messages);
      final executor = AiToolExecutor(confirm: _confirmTool);
      return AiAgent(_service).run(
        config: config,
        history: history,
        toolHandler: executor.execute,
      );
    });
    if (!mounted || reply == null) {
      return;
    }
    setState(() {
      _messages.add(AiChatMessage(role: 'assistant', content: reply));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildSettings() {
    final appLocalizations = context.appLocalizations;
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text('AI', style: context.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _baseUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'API ${appLocalizations.url}',
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
                labelText: 'API ${appLocalizations.key}',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  tooltip: 'API Key',
                  onPressed: () {
                    setState(() {
                      _hideKey = !_hideKey;
                    });
                  },
                  icon: Icon(
                    _hideKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_models.isEmpty)
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedModel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
                items: _models
                    .map(
                      (model) => DropdownMenuItem(
                        value: model,
                        child: Text(
                          model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (model) {
                  setState(() {
                    _selectedModel = model;
                    _modelController.text = model ?? '';
                  });
                },
              ),
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
                  label: Text(appLocalizations.connected),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _saveConfig,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(appLocalizations.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(28),
      child: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _messages.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 52,
                        color: context.colorScheme.primary.withAlpha(150),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('messages'),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(18),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: !_busy
                ? const SizedBox.shrink(key: ValueKey(false))
                : const LinearProgressIndicator(
                    key: ValueKey(true),
                    minHeight: 2,
                  ),
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
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: context.appLocalizations.messageTest,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onSubmitted: (_) => _sendMessage(),
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
                  Expanded(child: _buildConversation()),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: 300, child: _buildSettings()),
                const SizedBox(height: 12),
                Expanded(child: _buildConversation()),
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
    final colorScheme = context.colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
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
