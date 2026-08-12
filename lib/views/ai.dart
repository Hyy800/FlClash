import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ai/ai_service.dart';
import 'package:fl_clash/features/ai/ai_tools.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

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
  String _agentStatus = '';
  String _requestError = '';
  String? _failedSessionId;
  String? _failedMessageId;
  List<AiAttachment> _pendingAttachments = const [];
  String _pendingDelta = '';
  bool _frameScheduled = false;
  bool _busy = false;
  bool _hideKey = true;
  StateSetter? _apiSettingsState;

  void _setPageState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
    _apiSettingsState?.call(() {});
  }

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
    _setPageState(() => _busy = true);
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
      if (mounted) _setPageState(() => _busy = false);
    }
  }

  Future<void> _fetchModels() async {
    final models = await _run(
      () => _service.fetchModels(_draftConfig(requireModel: false)),
    );
    if (!mounted || models == null) return;
    if (models.isEmpty) {
      globalState.showNotifier('The API returned no models.');
      return;
    }
    _setPageState(() {
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
              clipBehavior: Clip.antiAlias,
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
                          final selected =
                              model == _modelController.text.trim();
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
      _setPageState(() => _modelController.text = selected);
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

  Future<void> _showApiSettings() async {
    if (_busy) return;
    final config = ref.read(aiSettingProvider);
    _setPageState(() {
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
      _models = config.cachedModels;
      _protocol = config.protocol;
    });
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          _apiSettingsState = setDialogState;
          return AlertDialog(
            clipBehavior: Clip.antiAlias,
            title: Row(
              children: [
                const Icon(Icons.api_rounded),
                const SizedBox(width: 10),
                const Expanded(child: Text('API')),
                IconButton(
                  tooltip: context.appLocalizations.cancel,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            content: SizedBox(
              width: 400,
              height: 500,
              child: _buildSettings(panel: false),
            ),
          );
        },
      ),
    );
    _apiSettingsState = null;
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

  void _updateToolStatus(List<AiToolCall> calls) {
    if (!mounted) return;
    final l10n = context.appLocalizations;
    final names = calls.map((call) => call.name).toSet();
    final target = switch (names) {
      final values
          when values.any(
            (name) => name.contains('profile') || name == 'validate_yaml',
          ) =>
        l10n.profiles,
      final values
          when values.any(
            (name) => name.contains('proxy') || name.contains('delay'),
          ) =>
        l10n.proxies,
      final values when values.any((name) => name.contains('rule')) =>
        l10n.rule,
      final values
          when values.any(
            (name) => name.contains('setting') || name == 'get_app_state',
          ) =>
        l10n.settings,
      final values when values.any((name) => name.contains('skill')) =>
        l10n.import,
      _ => '',
    };
    setState(() {
      _agentStatus = calls.isEmpty
          ? ''
          : target.isEmpty
          ? l10n.loading
          : '${l10n.loading} $target';
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if ((content.isEmpty && _pendingAttachments.isEmpty) || _busy) return;
    AiConfig config;
    try {
      config = _draftConfig();
    } catch (error) {
      globalState.showNotifier(error.toString());
      return;
    }
    final sessionId = ref.read(aiSessionsProvider).activeSessionId;
    final attachments = _pendingAttachments;
    _messageController.clear();
    setState(() => _pendingAttachments = const []);
    final userMessage = AiChatMessage(
      role: 'user',
      content: content,
      attachments: attachments,
    );
    await ref
        .read(aiSessionsProvider.notifier)
        .addMessage(sessionId, userMessage);
    setState(() {
      _streamedText = '';
      _pendingDelta = '';
    });
    _scrollToBottom();
    await _generateReply(
      sessionId,
      draft: config,
      sourceMessageId: userMessage.id,
    );
  }

  Future<void> _generateReply(
    String sessionId, {
    AiConfig? draft,
    String? sourceMessageId,
  }) async {
    if (_busy) return;
    AiConfig config;
    try {
      config = draft ?? _draftConfig();
    } catch (error) {
      globalState.showNotifier(error.toString());
      return;
    }
    _setPageState(() {
      _busy = true;
      _streamedText = '';
      _pendingDelta = '';
      _agentStatus = '';
      _requestError = '';
      _failedSessionId = null;
      _failedMessageId = null;
    });
    try {
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
      final reply = await AiAgent(_service).run(
        config: config,
        history: session.messages,
        summary: session.summary,
        skills: ref.read(aiSkillsProvider),
        toolHandler: executor.execute,
        onDelta: _appendDelta,
        onToolStatus: _updateToolStatus,
      );
      if (!mounted || reply.trim().isEmpty) {
        throw StateError(
          mounted
              ? context.appLocalizations.aiEmptyResponse
              : 'The model returned an empty response.',
        );
      }
      setState(() {
        _streamedText = '';
        _pendingDelta = '';
        _agentStatus = '';
      });
      await ref
          .read(aiSessionsProvider.notifier)
          .addMessage(
            sessionId,
            AiChatMessage(role: 'assistant', content: reply),
          );
      _scrollToBottom();
    } catch (error, stackTrace) {
      commonPrint.log(
        'AI message failed: $error, $stackTrace',
        logLevel: LogLevel.warning,
      );
      if (mounted) {
        setState(() {
          _streamedText = '';
          _pendingDelta = '';
          _agentStatus = '';
          _requestError = error.toString();
          _failedSessionId = sessionId;
          _failedMessageId = sourceMessageId;
        });
      }
    } finally {
      if (mounted) _setPageState(() => _busy = false);
    }
  }

  Future<void> _retryFailedMessage() async {
    final sessionId = _failedSessionId;
    final messageId = _failedMessageId;
    if (sessionId == null ||
        messageId == null ||
        sessionId != ref.read(aiSessionsProvider).activeSessionId) {
      return;
    }
    final store = ref.read(aiSessionsProvider);
    final session = store.activeSession;
    final index = session.messages.indexWhere((item) => item.id == messageId);
    if (index < 0) return;
    await ref
        .read(aiSessionsProvider.notifier)
        .replaceMessages(session.id, session.messages.sublist(0, index + 1));
    await _generateReply(session.id, sourceMessageId: messageId);
  }

  Future<void> _editMessage(AiChatMessage message) async {
    if (_busy || message.role != 'user') return;
    final controller = TextEditingController(text: message.content);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        clipBehavior: Clip.antiAlias,
        title: Text(context.appLocalizations.edit),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.appLocalizations.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.send_rounded),
            label: Text(context.appLocalizations.submit),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    final session = ref.read(aiSessionsProvider).activeSession;
    final index = session.messages.indexWhere((item) => item.id == message.id);
    if (index < 0) return;
    final edited = AiChatMessage(
      id: message.id,
      role: 'user',
      content: value.trim(),
      attachments: message.attachments,
      createdAt: message.createdAt,
    );
    await ref.read(aiSessionsProvider.notifier).replaceMessages(session.id, [
      ...session.messages.sublist(0, index),
      edited,
    ]);
    await _generateReply(session.id, sourceMessageId: edited.id);
  }

  Future<Uint8List?> _readClipboardFile(
    DataReader reader,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    final progress = reader.getFile(format, (file) async {
      try {
        completer.complete(await file.readAll());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }, onError: (error) => completer.completeError(error));
    if (progress == null) completer.complete(null);
    return completer.future;
  }

  void _insertClipboardText(String text) {
    final value = _messageController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final nextText = value.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  Future<void> _pasteConversationClipboard() async {
    if (_busy) return;
    try {
      final reader = await SystemClipboard.instance?.read();
      FileFormat? imageFormat;
      String? mimeType;
      String? extension;
      if (reader?.canProvide(Formats.png) == true) {
        imageFormat = Formats.png;
        mimeType = 'image/png';
        extension = 'png';
      } else if (reader?.canProvide(Formats.jpeg) == true) {
        imageFormat = Formats.jpeg;
        mimeType = 'image/jpeg';
        extension = 'jpg';
      } else if (reader?.canProvide(Formats.webp) == true) {
        imageFormat = Formats.webp;
        mimeType = 'image/webp';
        extension = 'webp';
      }
      if (reader != null && imageFormat != null) {
        if (_pendingAttachments.length >= 4) return;
        final bytes = await _readClipboardFile(reader, imageFormat);
        if (bytes == null || bytes.isEmpty) return;
        if (bytes.length > 8 * 1024 * 1024) {
          throw FormatException(context.appLocalizations.attachmentTooLarge);
        }
        if (!mounted) return;
        setState(() {
          _pendingAttachments = [
            ..._pendingAttachments,
            AiAttachment(
              name:
                  'clipboard-${DateTime.now().millisecondsSinceEpoch}.$extension',
              mimeType: mimeType!,
              data: base64Encode(bytes),
            ),
          ];
        });
        return;
      }
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text?.isNotEmpty == true) _insertClipboardText(data!.text!);
    } catch (error) {
      globalState.showNotifier(
        error is FormatException
            ? error.message
            : context.appLocalizations.unsupportedAttachment,
      );
    }
  }

  Future<void> _pickConversationAttachment() async {
    if (_busy || _pendingAttachments.length >= 4) return;
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return;
    try {
      final bytes = await platformFile.readBytes();
      final extension = platformFile.name.split('.').last.toLowerCase();
      final imageMime = switch (extension) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => null,
      };
      AiAttachment attachment;
      if (imageMime != null) {
        if (bytes.length > 8 * 1024 * 1024) {
          throw FormatException(context.appLocalizations.attachmentTooLarge);
        }
        attachment = AiAttachment(
          name: platformFile.name,
          mimeType: imageMime,
          data: base64Encode(bytes),
        );
      } else {
        if (bytes.length > 2 * 1024 * 1024) {
          throw FormatException(context.appLocalizations.attachmentTooLarge);
        }
        final text = utf8.decode(bytes);
        attachment = AiAttachment(
          name: platformFile.name,
          mimeType: 'text/plain',
          text: text,
        );
      }
      if (mounted) {
        setState(
          () => _pendingAttachments = [..._pendingAttachments, attachment],
        );
      }
    } catch (error) {
      globalState.showNotifier(
        error is FormatException
            ? error.message
            : context.appLocalizations.unsupportedAttachment,
      );
    }
  }

  Future<void> _createSession() async {
    if (_busy) return;
    final canReuse = ref.read(aiSessionsProvider).canReuseActiveSession;
    await ref.read(aiSessionsProvider.notifier).createSession();
    if (canReuse || !mounted) return;
    _clearConversationUi();
    _scrollToBottom();
  }

  Future<void> _selectSession(String id) async {
    final store = ref.read(aiSessionsProvider);
    if (id == store.activeSessionId) return;
    await ref.read(aiSessionsProvider.notifier).selectSession(id);
    if (!mounted) return;
    _clearConversationUi();
    _scrollToBottom();
  }

  void _clearConversationUi() {
    _messageController.clear();
    setState(() {
      _streamedText = '';
      _pendingDelta = '';
      _frameScheduled = false;
      _agentStatus = '';
      _requestError = '';
      _failedSessionId = null;
      _failedMessageId = null;
      _pendingAttachments = const [];
    });
  }

  Future<AiSkill?> _importSkillContent({
    required String name,
    required String content,
  }) async {
    try {
      final skill = await ref
          .read(aiSkillsProvider.notifier)
          .importSkill(name: name, content: content);
      if (mounted) {
        globalState.showNotifier(
          '${context.appLocalizations.import}: ${skill.name}',
        );
      }
      return skill;
    } catch (error) {
      globalState.showNotifier(error.toString());
      return null;
    }
  }

  Future<AiSkill?> _importSkillFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    if (platformFile == null) return null;
    try {
      final content = utf8.decode(await platformFile.readBytes());
      final fallbackName = platformFile.name.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      );
      final name = AiSkill.inferName(content, fallback: fallbackName);
      final skill = await _importSkillContent(name: name, content: content);
      return skill;
    } catch (error) {
      globalState.showNotifier(error.toString());
      return null;
    }
  }

  Future<void> _showSkillEditor() async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    final draft = await showDialog<({String name, String content})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        clipBehavior: Clip.antiAlias,
        title: Text('${context.appLocalizations.import} Skill'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.appLocalizations.name,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                minLines: 10,
                maxLines: 16,
                decoration: InputDecoration(
                  labelText: context.appLocalizations.content,
                  alignLabelWithHint: true,
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
          FilledButton.icon(
            onPressed: () {
              final content = contentController.text.trim();
              final name = nameController.text.trim().isEmpty
                  ? AiSkill.inferName(content)
                  : nameController.text.trim();
              Navigator.pop(dialogContext, (name: name, content: content));
            },
            icon: const Icon(Icons.download_done_rounded),
            label: Text(context.appLocalizations.import),
          ),
        ],
      ),
    );
    nameController.dispose();
    contentController.dispose();
    if (draft != null) {
      await _importSkillContent(name: draft.name, content: draft.content);
    }
  }

  Future<void> _showSkills() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, dialogRef, _) {
          final skills = dialogRef.watch(aiSkillsProvider);
          return AlertDialog(
            clipBehavior: Clip.antiAlias,
            title: const Row(
              children: [
                Icon(Icons.extension_rounded),
                SizedBox(width: 10),
                Expanded(child: Text('Skills')),
              ],
            ),
            content: SizedBox(
              width: 620,
              height: 430,
              child: skills.isEmpty
                  ? const Center(
                      child: Icon(Icons.extension_off_rounded, size: 48),
                    )
                  : ListView.separated(
                      itemCount: skills.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final skill = skills[index];
                        return ListTile(
                          leading: Switch(
                            value: skill.enabled,
                            onChanged: (value) => dialogRef
                                .read(aiSkillsProvider.notifier)
                                .setEnabled(skill.id, value),
                          ),
                          title: Text(skill.name),
                          subtitle: Text(
                            '${skill.content.length} ${context.appLocalizations.content}',
                          ),
                          trailing: IconButton(
                            tooltip: context.appLocalizations.delete,
                            onPressed: () => dialogRef
                                .read(aiSkillsProvider.notifier)
                                .deleteSkill(skill.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton.icon(
                onPressed: _showSkillEditor,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(context.appLocalizations.content),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _importSkillFile(),
                icon: const Icon(Icons.file_open_rounded),
                label: Text(context.appLocalizations.importFile),
              ),
              IconButton(
                tooltip: context.appLocalizations.cancel,
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _renameSession(AiSession session) async {
    final controller = TextEditingController(text: session.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.antiAlias,
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
      await ref
          .read(aiSessionsProvider.notifier)
          .renameSession(session.id, value);
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

  Widget _buildSettings({bool panel = true}) {
    final l10n = context.appLocalizations;
    final content = SingleChildScrollView(
      padding: EdgeInsets.all(panel ? 18 : 4),
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
                onPressed: () => _setPageState(() => _hideKey = !_hideKey),
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
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) =>
                      _setPageState(() => _protocol = value ?? _protocol),
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
    );
    if (!panel) return content;
    return AppGlassPanel(
      borderRadius: BorderRadius.circular(28),
      child: content,
    );
  }

  Widget _buildSessionHeader(AiSessionStore store) {
    final session = store.activeSession;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
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
          PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: context.appLocalizations.more,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            color: context.colorScheme.surfaceContainerLow,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            onSelected: _selectSession,
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
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.expand_more_rounded),
            ),
          ),
          IconButton(
            tooltip: context.appLocalizations.add,
            onPressed: _busy ? null : _createSession,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: context.appLocalizations.more,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            color: context.colorScheme.surfaceContainerLow,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
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
      if (_agentStatus.isNotEmpty)
        AiChatMessage(role: 'status', content: _agentStatus),
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
            child: visibleMessages.isEmpty
                ? Center(
                    key: ValueKey('empty-${store.activeSessionId}'),
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
                    itemBuilder: (_, index) {
                      final message = visibleMessages[index];
                      final failed =
                          message.id == _failedMessageId &&
                          _failedSessionId == store.activeSessionId;
                      return _MessageBubble(
                        message: message,
                        busy: _busy,
                        failed: failed,
                        error: failed ? _requestError : '',
                        onRetry: failed ? _retryFailedMessage : null,
                        onEdit: message.role == 'user'
                            ? () => _editMessage(message)
                            : null,
                      );
                    },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pendingAttachments.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (
                        var index = 0;
                        index < _pendingAttachments.length;
                        index++
                      )
                        InputChip(
                          avatar: Icon(
                            _pendingAttachments[index].isImage
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _pendingAttachments[index].name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: _busy
                              ? null
                              : () => setState(() {
                                  _pendingAttachments = [
                                    ..._pendingAttachments.sublist(0, index),
                                    ..._pendingAttachments.sublist(index + 1),
                                  ];
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: context.appLocalizations.addAttachment,
                      onPressed: _busy ? null : _pickConversationAttachment,
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(
                            LogicalKeyboardKey.keyV,
                            control: true,
                          ): _pasteConversationClipboard,
                          const SingleActivator(
                            LogicalKeyboardKey.keyV,
                            meta: true,
                          ): _pasteConversationClipboard,
                        },
                        child: Focus(
                          onKeyEvent: (_, event) {
                            final isEnter =
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.numpadEnter;
                            if (event is KeyDownEvent &&
                                isEnter &&
                                !HardwareKeyboard.instance.isShiftPressed) {
                              _sendMessage();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _messageController,
                            enabled: !_busy,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: context.appLocalizations.aiInputHint,
                              border: InputBorder.none,
                              filled: false,
                            ),
                          ),
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
      actions: [
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _showSkills,
          icon: const Icon(Icons.extension_rounded),
          label: const Text('Skills'),
        ),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _showApiSettings,
          icon: const Icon(Icons.api_rounded),
          label: const Text('API'),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: _buildConversation(sessions),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;
  final bool busy;
  final bool failed;
  final String error;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;

  const _MessageBubble({
    required this.message,
    required this.busy,
    required this.failed,
    required this.error,
    required this.onRetry,
    required this.onEdit,
  });

  Future<void> _showContextMenu(BuildContext bubbleContext) async {
    if (busy || onEdit == null) return;
    final overlay = Overlay.of(bubbleContext).context.findRenderObject();
    final bubble = bubbleContext.findRenderObject();
    if (overlay is! RenderBox || bubble is! RenderBox) return;
    final bubbleTopLeft = bubble.localToGlobal(Offset.zero, ancestor: overlay);
    final bubbleRect = bubbleTopLeft & bubble.size;
    final anchorRect = Rect.fromLTRB(
      bubbleRect.left - 8,
      bubbleRect.top,
      bubbleRect.left,
      bubbleRect.bottom,
    );
    final action = await showMenu<String>(
      context: bubbleContext,
      position: RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size),
      constraints: const BoxConstraints(minWidth: 112, maxWidth: 140),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      color: bubbleContext.colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 19),
              const SizedBox(width: 10),
              Text(bubbleContext.appLocalizations.edit),
            ],
          ),
        ),
      ],
    );
    if (action == 'edit') onEdit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isStatus = message.role == 'status';
    final bubble = Builder(
      builder: (bubbleContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: onEdit == null
            ? null
            : (_) => _showContextMenu(bubbleContext),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
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
          clipBehavior: Clip.antiAlias,
          child: isStatus
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      message.content,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : isUser
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.content.isNotEmpty)
                      SelectableText(
                        message.content,
                        style: context.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    if (message.attachments.isNotEmpty) ...[
                      if (message.content.isNotEmpty) const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: message.attachments
                            .map(
                              (item) => Chip(
                                avatar: Icon(
                                  item.isImage
                                      ? Icons.image_outlined
                                      : Icons.description_outlined,
                                  size: 16,
                                ),
                                label: Text(item.name),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                )
              : _MarkdownMessage(content: message.content),
        ),
      ),
    );
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed) ...[
              IconButton(
                tooltip: error.isEmpty
                    ? context.appLocalizations.messageSendFailed
                    : error,
                onPressed: busy ? null : onRetry,
                color: context.colorScheme.error,
                icon: const Icon(Icons.error_rounded),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}

class _MarkdownMessage extends StatelessWidget {
  final String content;

  const _MarkdownMessage({required this.content});

  List<InlineSpan> _parseInline(BuildContext context, String value) {
    final baseStyle = context.textTheme.bodyMedium?.copyWith(height: 1.5);
    final codeStyle = baseStyle?.copyWith(
      fontFamily: 'JetBrainsMono',
      backgroundColor: context.colorScheme.surfaceContainerHighest,
      color: context.colorScheme.onSurface,
    );
    final pattern = RegExp(r'(\*\*.+?\*\*|`[^`]+`|(?<!\*)\*[^*\n]+\*)');
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: value.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: codeStyle,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      offset = match.end;
    }
    if (offset < value.length) {
      spans.add(TextSpan(text: value.substring(offset)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final spans = <InlineSpan>[];
    var codeBlock = false;
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index];
      if (line.trimLeft().startsWith('```')) {
        codeBlock = !codeBlock;
        continue;
      }
      TextStyle? lineStyle = context.textTheme.bodyMedium?.copyWith(
        height: 1.5,
      );
      if (codeBlock) {
        lineStyle = lineStyle?.copyWith(
          fontFamily: 'JetBrainsMono',
          backgroundColor: context.colorScheme.surfaceContainerHighest,
        );
      } else {
        final heading = RegExp(r'^(#{1,4})\s+').firstMatch(line);
        if (heading != null) {
          line = line.substring(heading.end);
          lineStyle = context.textTheme.titleMedium?.copyWith(height: 1.55);
        } else if (line.startsWith('- ')) {
          line = '• ${line.substring(2)}';
        }
      }
      spans.add(
        TextSpan(
          style: lineStyle,
          children: codeBlock
              ? [TextSpan(text: line)]
              : _parseInline(context, line),
        ),
      );
      if (index != lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return SelectableText.rich(
      TextSpan(
        style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
        children: spans,
      ),
    );
  }
}
