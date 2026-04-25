import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_locale.dart';
import '../data/api_client.dart';
import '../data/app_database.dart';
import '../data/auth_store.dart';
import '../models/app_models.dart';
import '../widgets/message_bubble.dart';
import '../widgets/shino_mark.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.database,
    required this.authStore,
    required this.apiClient,
    required this.session,
    required this.themeMode,
    required this.onSessionChanged,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.onLoggedOut,
  });

  final AppDatabase database;
  final AuthStore authStore;
  final ApiClient apiClient;
  final AuthSession session;
  final ThemeMode themeMode;
  final ValueChanged<AuthSession> onSessionChanged;
  final ValueChanged<Locale?> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function() onLoggedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _messagesController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  List<ChatSession> _sessions = const [];

  bool _busy = false;
  bool _syncing = false;
  String? _error;
  String? _selectedConversationId;
  String? _streamingText;
  String? _streamingReasoning;
  String? _streamConversationId;
  String? _selectedModelAlias;
  String? _selectedPersonaId;
  String? _lastSyncedAt;
  List<CachedModel> _models = const [];
  List<_PendingAttachment> _pendingAttachments = const [];
  List<_LocalPendingMessage> _pendingMessages = const [];
  final Map<String, List<String>> _pendingImagePathsByText = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_hydrate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composerController.dispose();
    _messagesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncNow());
    }
  }

  Future<void> _hydrate() async {
    setState(() => _busy = true);
    try {
      final bootstrap = await widget.apiClient.bootstrap(widget.session);
      final models = List<Map<String, dynamic>>.from(
        bootstrap['models'] as List<dynamic>? ?? const [],
      );
      final personas = List<Map<String, dynamic>>.from(
        bootstrap['personas'] as List<dynamic>? ?? const [],
      );
      await widget.database.applySyncPayload(
        conversations: const [],
        messages: const [],
        models: models,
        personas: personas,
      );
      await _refreshChoices();
      await _syncNow();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshChoices() async {
    final models = await widget.database.getModels();
    final personas = await widget.database.getPersonas();
    if (!mounted) return;
    setState(() {
      _models = models;
      if (_selectedModelAlias == null ||
          !models.any((item) => item.alias == _selectedModelAlias)) {
        _selectedModelAlias = models.isEmpty ? null : models.first.alias;
      }
      _selectedPersonaId ??= personas.isEmpty ? null : personas.first.id;
    });
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final since = await widget.database.getSyncCursor();
      final payload = await widget.apiClient.sync(widget.session, since: since);
      await _downloadMissingImages(payload.messages);
      await widget.database.applySyncPayload(
        conversations: payload.conversations,
        messages: _mergeLocalImages(payload.messages),
        models: payload.models,
        personas: payload.personas,
      );
      await widget.database.setSyncCursor(payload.serverTime);
      await _refreshChoices();
      final sessions = await widget.database.getSessions();
      if (mounted) {
        setState(() {
          _lastSyncedAt = payload.serverTime;
          _sessions = sessions;
          _pendingMessages = _pendingMessages.where((pending) {
            return !payload.messages.any((message) {
              if (message['role'] != 'user') return false;
              if (message['conversation_id'] != pending.conversationId) {
                return false;
              }
              if (message['content'] != pending.content) return false;
              final attachments =
                  message['attachments'] as List<dynamic>? ?? const [];
              if (pending.imageHashes.isEmpty) return attachments.isEmpty;
              return pending.imageHashes.every(
                (hash) => attachments.any(
                  (attachment) =>
                      attachment is Map && attachment['sha256'] == hash,
                ),
              );
            });
          }).toList();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _composerController.text.trim();
    if ((content.isEmpty && _pendingAttachments.isEmpty) || _busy) return;
    FocusScope.of(context).unfocus();
    final attachments = _pendingAttachments;
    final messageText = content.isEmpty
        ? _attachmentFallbackText(attachments)
        : content;
    final attachmentPayload = await _buildAttachmentPayload(attachments);
    var conversationId = _selectedConversationId;
    if (conversationId == null) {
      try {
        final conversation = await widget.apiClient.createConversation(
          widget.session,
          title: _summarizeTitle(messageText),
          modelAlias: _resolveModelAlias(),
          personaId: _selectedPersonaId,
        );
        conversationId = conversation['id'] as String?;
        if (conversationId != null) {
          await widget.database.upsertConversation(conversation);
        }
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''),
          );
        }
        return;
      }
    }
    if (conversationId != null) {
      setState(() {
        _selectedConversationId = conversationId;
        _streamConversationId = conversationId;
      });
    }
    final imageAttachments = attachmentPayload
        .where((item) => item['type'] == 'image')
        .toList();
    final imagePaths = imageAttachments
        .map((item) => item['local_path'] as String?)
        .whereType<String>()
        .toList();
    final pendingMessageId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    if (imagePaths.isNotEmpty) {
      _pendingImagePathsByText['$conversationId\n$messageText'] = imagePaths;
      for (final item in imageAttachments) {
        final sha = item['sha256'] as String?;
        final path = item['local_path'] as String?;
        if (sha != null && path != null) {
          _pendingImagePathsByText['$conversationId\n$sha'] = [path];
        }
      }
    }
    setState(() {
      _busy = true;
      _error = null;
      _streamingText = '';
      _streamingReasoning = '';
      _streamConversationId = conversationId;
      _pendingAttachments = const [];
      if (conversationId != null) {
        _pendingMessages = [
          ..._pendingMessages,
          _LocalPendingMessage(
            id: pendingMessageId,
            conversationId: conversationId,
            content: messageText,
            imagePaths: imagePaths,
            imageHashes: imageAttachments
                .map((item) => item['sha256'] as String?)
                .whereType<String>()
                .toList(),
            createdAt: DateTime.now(),
          ),
        ];
      }
    });
    _composerController.clear();

    try {
      await for (final event in widget.apiClient.streamChat(
        session: widget.session,
        content: messageText,
        attachments: attachmentPayload,
        conversationId: conversationId,
        modelAlias: _resolveModelAlias(),
        personaId: _selectedPersonaId,
      )) {
        if (!mounted) return;
        switch (event.type) {
          case 'meta':
            final conversationId = event.payload['conversation_id'] as String?;
            if (conversationId != null) {
              setState(() {
                _selectedConversationId = conversationId;
                _streamConversationId = conversationId;
              });
            }
            unawaited(_scrollToBottom());
            break;
          case 'reasoning_delta':
            setState(() {
              _streamingReasoning =
                  '${_streamingReasoning ?? ''}${event.payload['content'] as String? ?? ''}';
            });
            unawaited(_scrollToBottom());
            break;
          case 'delta':
            setState(() {
              _streamingText =
                  '${_streamingText ?? ''}${event.payload['content'] as String? ?? ''}';
            });
            unawaited(_scrollToBottom());
            break;
          case 'done':
            setState(() {
              _streamingText = null;
              _streamingReasoning = null;
            });
            await _syncNow();
            if (mounted) {
              setState(() {
                _pendingMessages = _pendingMessages
                    .where((item) => item.id != pendingMessageId)
                    .toList();
              });
            }
            unawaited(_scrollToBottom());
            break;
          case 'error':
            setState(
              () => _error =
                  event.payload['message'] as String? ?? 'Streaming failed',
            );
            break;
        }
      }
      await _syncNow();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _streamingText = null;
          _streamingReasoning = null;
        });
      }
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      await widget.apiClient.deleteConversation(widget.session, id);
      if (_selectedConversationId == id) {
        setState(() => _selectedConversationId = null);
      }
      await _syncNow();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  String _attachmentFallbackText(List<_PendingAttachment> attachments) {
    if (attachments.isEmpty) return '';
    if (attachments.length == 1) return 'Please describe this attachment.';
    return 'Please describe these attachments.';
  }

  List<Map<String, dynamic>> _mergeLocalImages(
    List<Map<String, dynamic>> messages,
  ) {
    return messages.map((message) {
      if (message['role'] != 'user') return message;
      final key = '${message['conversation_id']}\n${message['content']}';
      final imagePaths = <String>{
        ...?_pendingImagePathsByText[key],
        for (final attachment in message['attachments'] as List<dynamic>? ?? [])
          ...?_pendingImagePathsByText['${message['conversation_id']}\n${(attachment as Map?)?['sha256']}'],
      }.toList();
      if (imagePaths.isEmpty) return message;
      return {...message, 'local_image_paths': imagePaths.join('\n')};
    }).toList();
  }

  Future<void> _downloadMissingImages(
    List<Map<String, dynamic>> messages,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/attachment_images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    for (final message in messages) {
      if (message['role'] != 'user') continue;
      final conversationId = message['conversation_id'] as String?;
      if (conversationId == null) continue;
      final attachments = message['attachments'] as List<dynamic>? ?? const [];
      for (final attachment in attachments) {
        if (attachment is! Map || attachment['type'] != 'image') continue;
        final hash = attachment['sha256'] as String?;
        if (hash == null ||
            _pendingImagePathsByText['$conversationId\n$hash'] != null) {
          continue;
        }
        final ext = (attachment['mime_type'] as String?) == 'image/png'
            ? 'png'
            : 'jpg';
        final file = File('${imageDir.path}/$hash.$ext');
        if (!await file.exists()) {
          final bytes = await widget.apiClient.fetchAttachment(
            widget.session,
            hash,
          );
          await file.writeAsBytes(bytes, flush: true);
        }
        _pendingImagePathsByText['$conversationId\n$hash'] = [file.path];
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buildAttachmentPayload(
    List<_PendingAttachment> attachments,
  ) async {
    final payload = <Map<String, dynamic>>[];
    for (final item in attachments) {
      if (item.kind == _AttachmentKind.file) {
        payload.add({'type': 'file', 'name': item.label});
        continue;
      }
      final bytes = await File(item.path).readAsBytes();
      if (bytes.length > 900 * 1024) {
        throw Exception(
          'Image is still too large after compression. Please choose a smaller image.',
        );
      }
      final sha256Hex = sha256.convert(bytes).toString();
      final mimeType = item.label.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      payload.add({
        'type': 'image',
        'name': item.label,
        'mime_type': mimeType,
        'sha256': sha256Hex,
        'local_path': item.path,
        'data': base64Encode(bytes),
      });
    }
    return payload;
  }

  String _summarizeTitle(String content) {
    final squashed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (squashed.isEmpty) return 'New chat';
    if (squashed.length <= 40) return squashed;
    return '${squashed.substring(0, 39).trimRight()}...';
  }

  String? _resolveModelAlias() {
    if (_selectedModelAlias != null) return _selectedModelAlias;
    if (_models.isNotEmpty) return _models.first.alias;
    return null;
  }

  void _showPickerError({
    required Object error,
    required String zhAction,
    required String enAction,
  }) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = raw.toLowerCase();
    final likelyPermissionIssue =
        error is PlatformException ||
        normalized.contains('permission') ||
        normalized.contains('denied') ||
        normalized.contains('not authorized') ||
        normalized.contains('access');
    final fallback = appText(
      context,
      zh: '$zhAction失败，请到系统设置中开启相机、照片与文件权限后重试。',
      en:
          '$enAction failed. Please enable camera, photos, and files permissions in system settings and try again.',
    );
    if (!mounted) return;
    setState(() {
      _error = raw.isEmpty || likelyPermissionIssue ? fallback : raw;
    });
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      final next = result.files
          .map(
            (file) => _PendingAttachment(
              label: file.name,
              path: file.path ?? file.name,
              kind: _AttachmentKind.file,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _error = null;
        _pendingAttachments = [..._pendingAttachments, ...next];
      });
    } catch (error) {
      _showPickerError(error: error, zhAction: '选择文件', enAction: 'File pick');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 35,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;
      setState(() {
        _error = null;
        _pendingAttachments = [
          ..._pendingAttachments,
          _PendingAttachment(
            label: image.name,
            path: image.path,
            kind: _AttachmentKind.image,
          ),
        ];
      });
    } catch (error) {
      _showPickerError(error: error, zhAction: '选择图片', enAction: 'Image pick');
    }
  }

  Future<void> _captureImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 35,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;
      setState(() {
        _error = null;
        _pendingAttachments = [
          ..._pendingAttachments,
          _PendingAttachment(
            label: image.name,
            path: image.path,
            kind: _AttachmentKind.camera,
          ),
        ];
      });
    } catch (error) {
      _showPickerError(error: error, zhAction: '调用相机', enAction: 'Camera');
    }
  }

  Future<void> _scrollToBottom() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!_messagesController.hasClients) return;
    await _messagesController.animateTo(
      _messagesController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _startNewChat() {
    setState(() {
      _selectedConversationId = null;
      _streamConversationId = null;
      _streamingText = null;
      _streamingReasoning = null;
      _error = null;
      _pendingAttachments = const [];
      _pendingMessages = const [];
    });
  }

  Future<void> _pickModel() async {
    if (_models.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final model in _models)
                ListTile(
                  title: Text(model.alias),
                  subtitle: Text(model.upstreamModel),
                  trailing: model.alias == _selectedModelAlias
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(model.alias),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => _selectedModelAlias = selected);
    if (_selectedConversationId != null) {
      await widget.apiClient.updateConversation(
        widget.session,
        _selectedConversationId!,
        modelAlias: selected,
      );
      await _syncNow();
    }
  }

  Future<void> _renameConversation(ChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(appText(context, zh: '重命名会话', en: 'Rename conversation')),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: appText(context, zh: '标题', en: 'Title'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appText(context, zh: '取消', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(appText(context, zh: '保存', en: 'Save')),
            ),
          ],
        );
      },
    );
    if (nextTitle == null || nextTitle.isEmpty || nextTitle == session.title) {
      return;
    }
    try {
      await widget.apiClient.updateConversation(
        widget.session,
        session.id,
        title: nextTitle,
      );
      await _syncNow();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _openProfileSettings() async {
    final updated = await showModalBottomSheet<AuthSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      builder: (context) => _ProfileSettingsSheet(
        session: widget.session,
        apiClient: widget.apiClient,
        onLocaleChanged: widget.onLocaleChanged,
      ),
    );
    if (updated == null) return;
    widget.onSessionChanged(updated);
  }

  String _formatSyncLabel() {
    final value = _lastSyncedAt;
    if (value == null) {
      return appText(context, zh: '尚未同步', en: 'Not synced yet');
    }
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return appText(context, zh: '已同步', en: 'Synced');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return appText(context, zh: '上次同步 $hh:$mm', en: 'Last sync $hh:$mm');
  }

  String _sectionLabel(DateTime timestamp) {
    final zh = isChineseLocale(context);
    const enMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (zh) return '${timestamp.year}年${timestamp.month}月';
    return '${enMonths[timestamp.month - 1]} ${timestamp.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildHistoryDrawer(theme),
      backgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFFFF3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme),
            if (_error != null) _buildErrorBanner(theme),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildChatPane(theme),
              ),
            ),
            _buildComposer(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 34),
          ),
          Expanded(
            child: Text(
              _selectedConversationId == null
                  ? 'ShinoChat'
                  : appText(context, zh: '会话', en: 'Conversation'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _startNewChat,
            icon: const Icon(Icons.add_comment_outlined, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0x24B6786A),
        ),
        child: Text(
          _error!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFCF8C82),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final sessions = _sessions;
                  final groups = <String, List<ChatSession>>{};
                  for (final session in sessions) {
                    final parsed =
                        DateTime.tryParse(session.updatedAt)?.toLocal() ??
                        DateTime.now();
                    final key = _sectionLabel(parsed);
                    groups.putIfAbsent(key, () => []).add(session);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    children: [
                      Text(
                        appText(context, zh: '历史记录', en: 'History'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isDark
                                  ? const Color(0xFF8B8C92)
                                  : const Color(0xFF7B7E88),
                            ),
                          ),
                        ),
                        ...entry.value.map(
                          (session) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setState(
                                () => _selectedConversationId = session.id,
                              );
                              Navigator.of(context).pop();
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _renameConversation(session);
                                } else if (value == 'delete') {
                                  _deleteConversation(session.id);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(
                                    appText(context, zh: '重命名', en: 'Rename'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    appText(context, zh: '删除', en: 'Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF3A3A3F)
                        : const Color(0xFFD8DBE3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openProfileSettings,
                    child: _UserAvatar(session: widget.session, radius: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openProfileSettings,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _formatSyncLabel(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFF8B8C92)
                                    : const Color(0xFF7B7E88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.onThemeModeChanged(
                      widget.themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    ),
                    icon: Icon(
                      widget.themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                  IconButton(
                    onPressed: () async => widget.onLoggedOut(),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPane(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final conversationId = _selectedConversationId ?? _streamConversationId;
    if (conversationId == null) {
      return _buildEmptyState(theme);
    }
    return StreamBuilder<List<ChatMessage>>(
      stream: widget.database.watchMessages(conversationId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <ChatMessage>[];
        final localMessages = _pendingMessages
            .where((item) => item.conversationId == conversationId)
            .toList();
        final timeline = [
          for (final message in messages) _TimelineEntry.message(message),
          for (final local in localMessages) _TimelineEntry.local(local),
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (messages.isEmpty &&
            localMessages.isEmpty &&
            _streamingText == null &&
            _streamingReasoning == null) {
          return _buildEmptyState(theme);
        }
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : const Color(0xFFFFF3F7),
          ),
          child: ListView.builder(
            controller: _messagesController,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            itemCount:
                timeline.length +
                (_streamingText != null || _streamingReasoning != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < timeline.length) {
                final entry = timeline[index];
                final message = entry.message;
                if (message != null) {
                  return MessageBubble(
                    role: message.role,
                    content: message.content,
                    imagePaths: message.localImagePaths,
                    timestamp: message.createdAt
                        .substring(0, 16)
                        .replaceFirst('T', ' '),
                  );
                }
                final local = entry.local!;
                return MessageBubble(
                  role: 'user',
                  content: local.content,
                  timestamp: appText(context, zh: '发送中', en: 'Sending'),
                  imagePaths: local.imagePaths,
                );
              }
              if (_streamingText != null || _streamingReasoning != null) {
                return MessageBubble(
                  role: 'assistant',
                  content: _streamingText!,
                  timestamp: appText(context, zh: '实时', en: 'Live'),
                  isStreaming: true,
                  reasoning: _streamingReasoning,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ShinoMark(size: 46),
              const SizedBox(height: 18),
              Text(
                appText(context, zh: '开始聊天', en: 'Start chatting'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickModel,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isDark
                        ? const Color(0xFF2A2025)
                        : const Color(0xFFFFEAF1),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFC43E77)
                          : const Color(0xFFF2B6CB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _resolveModelAlias() ??
                            appText(context, zh: '选择模型', en: 'Pick model'),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D1D1F) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? const Color(0xFF2F2F33) : const Color(0xFFD9DCE4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingAttachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _pendingAttachments)
                      InputChip(
                        label: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                        avatar: Icon(switch (item.kind) {
                          _AttachmentKind.image => Icons.image_outlined,
                          _AttachmentKind.camera => Icons.photo_camera_outlined,
                          _AttachmentKind.file => Icons.attach_file_outlined,
                        }, size: 18),
                        onDeleted: () {
                          setState(() {
                            _pendingAttachments = _pendingAttachments
                                .where((entry) => entry != item)
                                .toList();
                          });
                        },
                      ),
                  ],
                ),
              ),
            if (_pendingAttachments.isNotEmpty) const SizedBox(height: 12),
            TextField(
              controller: _composerController,
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: appText(context, zh: '输入消息', en: 'Type a message'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      label: Text(
                        _resolveModelAlias() ??
                            appText(context, zh: '模型', en: 'Model'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                      onPressed: _pickModel,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _pickAttachments,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                IconButton(
                  onPressed: _pickImage,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  onPressed: _captureImage,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _sendMessage,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(46, 46),
                    fixedSize: const Size(46, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Icon(
                    _busy
                        ? Icons.hourglass_top_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _AttachmentKind { image, camera, file }

class _PendingAttachment {
  const _PendingAttachment({
    required this.label,
    required this.path,
    required this.kind,
  });

  final String label;
  final String path;
  final _AttachmentKind kind;
}

class _LocalPendingMessage {
  const _LocalPendingMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.imagePaths,
    required this.imageHashes,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String content;
  final List<String> imagePaths;
  final List<String> imageHashes;
  final DateTime createdAt;
}

class _TimelineEntry {
  const _TimelineEntry._({required this.createdAt, this.message, this.local});

  factory _TimelineEntry.message(ChatMessage message) {
    return _TimelineEntry._(
      createdAt: DateTime.tryParse(message.createdAt) ?? DateTime.now(),
      message: message,
    );
  }

  factory _TimelineEntry.local(_LocalPendingMessage local) {
    return _TimelineEntry._(createdAt: local.createdAt, local: local);
  }

  final DateTime createdAt;
  final ChatMessage? message;
  final _LocalPendingMessage? local;
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.session, required this.radius});

  final AuthSession session;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = session.avatarUrl.trim();
    final label =
        (session.displayName.isNotEmpty
                ? session.displayName
                : session.username)
            .characters
            .first
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE85D93),
      backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
      child: avatarUrl.isEmpty
          ? Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _ProfileSettingsSheet extends StatefulWidget {
  const _ProfileSettingsSheet({
    required this.session,
    required this.apiClient,
    required this.onLocaleChanged,
  });

  final AuthSession session;
  final ApiClient apiClient;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<_ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<_ProfileSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _avatarUrlController;
  final _passwordController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.session.username);
    _displayNameController = TextEditingController(
      text: widget.session.displayName,
    );
    _avatarUrlController = TextEditingController(
      text: widget.session.avatarUrl,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.apiClient.updateProfile(
        widget.session,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset + 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _UserAvatar(
                    session: widget.session.copyWith(
                      displayName: _displayNameController.text,
                      username: _usernameController.text,
                    ),
                    radius: 28,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    appText(context, zh: '用户设置', en: 'User settings'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: appText(context, zh: '用户名', en: 'Username'),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) => value == null || value.trim().isEmpty
                    ? appText(context, zh: '必填', en: 'Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: appText(context, zh: '显示名称', en: 'Display name'),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: appText(context, zh: '新密码', en: 'New password'),
                  hintText: appText(
                    context,
                    zh: '留空则不修改当前密码',
                    en: 'Leave blank to keep current password',
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    Localizations.localeOf(
                      context,
                    ).languageCode.toLowerCase().startsWith('zh')
                    ? 'zh'
                    : 'en',
                decoration: InputDecoration(
                  labelText: appText(context, zh: '语言', en: 'Language'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'zh',
                    child: Text(appText(context, zh: '中文', en: 'Chinese')),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(appText(context, zh: '英文', en: 'English')),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  widget.onLocaleChanged(Locale(value));
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB86559),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? appText(context, zh: '保存中...', en: 'Saving...')
                        : appText(context, zh: '保存', en: 'Save'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
