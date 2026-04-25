import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.userId,
    required this.modelAlias,
    required this.personaId,
    required this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String title;
  final String userId;
  final String? modelAlias;
  final String? personaId;
  final String lastMessagePreview;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  factory ChatSession.fromRow(QueryRow row) => ChatSession(
    id: row.read<String>('id'),
    title: row.read<String>('title'),
    userId: row.read<String>('user_id'),
    modelAlias: row.readNullable<String>('model_alias'),
    personaId: row.readNullable<String>('persona_id'),
    lastMessagePreview: row.read<String>('last_message_preview'),
    createdAt: row.read<String>('created_at'),
    updatedAt: row.read<String>('updated_at'),
    deletedAt: row.readNullable<String>('deleted_at'),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.content,
    required this.modelAlias,
    required this.upstreamModel,
    required this.status,
    required this.localImagePaths,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String? userId;
  final String role;
  final String content;
  final String? modelAlias;
  final String? upstreamModel;
  final String status;
  final List<String> localImagePaths;
  final List<Map<String, dynamic>> attachments;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  factory ChatMessage.fromRow(QueryRow row) => ChatMessage(
    id: row.read<String>('id'),
    conversationId: row.read<String>('conversation_id'),
    userId: row.readNullable<String>('user_id'),
    role: row.read<String>('role'),
    content: row.read<String>('content'),
    modelAlias: row.readNullable<String>('model_alias'),
    upstreamModel: row.readNullable<String>('upstream_model'),
    status: row.read<String>('status'),
    localImagePaths: decodeLocalImagePaths(
      row.readNullable<String>('local_image_paths'),
    ),
    attachments: decodeAttachments(row.readNullable<String>('attachments')),
    createdAt: row.read<String>('created_at'),
    updatedAt: row.read<String>('updated_at'),
    deletedAt: row.readNullable<String>('deleted_at'),
  );
}

class CachedModel {
  const CachedModel({
    required this.id,
    required this.alias,
    required this.upstreamModel,
    required this.enabled,
    required this.isDefault,
    required this.defaultTemperature,
    required this.defaultMaxTokens,
    required this.updatedAt,
  });

  final String id;
  final String alias;
  final String upstreamModel;
  final bool enabled;
  final bool isDefault;
  final double defaultTemperature;
  final int defaultMaxTokens;
  final String updatedAt;

  factory CachedModel.fromRow(QueryRow row) => CachedModel(
    id: row.read<String>('id'),
    alias: row.read<String>('alias'),
    upstreamModel: row.read<String>('upstream_model'),
    enabled: row.read<bool>('enabled'),
    isDefault: row.read<bool>('is_default'),
    defaultTemperature: row.read<double>('default_temperature'),
    defaultMaxTokens: row.read<int>('default_max_tokens'),
    updatedAt: row.read<String>('updated_at'),
  );
}

class CachedPersona {
  const CachedPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.defaultModelAlias,
    required this.temperature,
    required this.enabled,
    required this.isDefault,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String? defaultModelAlias;
  final double temperature;
  final bool enabled;
  final bool isDefault;
  final String updatedAt;

  factory CachedPersona.fromRow(QueryRow row) => CachedPersona(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    description: row.read<String>('description'),
    systemPrompt: row.read<String>('system_prompt'),
    defaultModelAlias: row.readNullable<String>('default_model_alias'),
    temperature: row.read<double>('temperature'),
    enabled: row.read<bool>('enabled'),
    isDefault: row.read<bool>('is_default'),
    updatedAt: row.read<String>('updated_at'),
  );
}

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => _createSchema(),
    onUpgrade: (migrator, from, to) async => _createSchema(),
    beforeOpen: (_) async {
      await _createSchema();
      await _ensureColumn('chat_messages', 'local_image_paths', 'TEXT');
      await _ensureColumn('chat_messages', 'attachments', 'TEXT');
    },
  );

  Future<void> _createSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        user_id TEXT NOT NULL,
        model_alias TEXT,
        persona_id TEXT,
        last_message_preview TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        user_id TEXT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        model_alias TEXT,
        upstream_model TEXT,
        status TEXT NOT NULL DEFAULT 'complete',
        local_image_paths TEXT,
        attachments TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cached_models (
        id TEXT PRIMARY KEY,
        alias TEXT NOT NULL,
        upstream_model TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        default_temperature REAL NOT NULL DEFAULT 0.6,
        default_max_tokens INTEGER NOT NULL DEFAULT 1200,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cached_personas (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        system_prompt TEXT NOT NULL DEFAULT '',
        default_model_alias TEXT,
        temperature REAL NOT NULL DEFAULT 0.6,
        enabled INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await _ensureColumn('chat_messages', 'local_image_paths', 'TEXT');
    await _ensureColumn('chat_messages', 'attachments', 'TEXT');
  }

  Future<void> _ensureColumn(String table, String column, String type) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    final exists = rows.any((row) => row.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Stream<List<ChatSession>> watchSessions() async* {
    yield await _fetchSessions();
    await for (final _ in tableUpdates(
      const TableUpdateQuery.onTableName('chat_sessions'),
    ).asBroadcastStream()) {
      yield await _fetchSessions();
    }
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) async* {
    yield await _fetchMessages(conversationId);
    await for (final _ in tableUpdates(
      const TableUpdateQuery.onTableName('chat_messages'),
    ).asBroadcastStream()) {
      yield await _fetchMessages(conversationId);
    }
  }

  Future<void> upsertConversation(Map<String, dynamic> item) async {
    await _upsertConversation(item);
    notifyUpdates({const TableUpdate('chat_sessions')});
  }

  Future<void> upsertMessage(Map<String, dynamic> item) async {
    await _upsertMessage(item);
    notifyUpdates({const TableUpdate('chat_messages')});
  }

  Future<void> clearUserData() async {
    await customStatement('DELETE FROM chat_messages');
    await customStatement('DELETE FROM chat_sessions');
    await customStatement('DELETE FROM sync_meta');
    notifyUpdates({
      const TableUpdate('chat_messages'),
      const TableUpdate('chat_sessions'),
      const TableUpdate('sync_meta'),
    });
  }

  Future<List<CachedModel>> getModels() async {
    final rows = await customSelect('''
        SELECT *
        FROM cached_models
        WHERE enabled = 1
        ORDER BY is_default DESC, alias ASC
      ''').get();
    return rows.map(CachedModel.fromRow).toList();
  }

  Future<List<ChatSession>> getSessions() => _fetchSessions();

  Future<List<CachedPersona>> getPersonas() async {
    final rows = await customSelect('''
        SELECT *
        FROM cached_personas
        WHERE enabled = 1
        ORDER BY is_default DESC, name ASC
      ''').get();
    return rows.map(CachedPersona.fromRow).toList();
  }

  Future<String?> getSyncCursor() async {
    final row = await customSelect(
      'SELECT value FROM sync_meta WHERE key = ?',
      variables: [Variable.withString('sync_cursor')],
    ).getSingleOrNull();
    return row?.readNullable<String>('value');
  }

  Future<void> setSyncCursor(String value) async {
    await customInsert(
      '''
        INSERT INTO sync_meta (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      variables: [
        Variable.withString('sync_cursor'),
        Variable.withString(value),
      ],
    );
    notifyUpdates({const TableUpdate('sync_meta')});
  }

  Future<void> applySyncPayload({
    required List<Map<String, dynamic>> conversations,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> models,
    required List<Map<String, dynamic>> personas,
  }) async {
    await transaction(() async {
      if (models.isNotEmpty) {
        await customStatement(
          'UPDATE cached_models SET enabled = 0, is_default = 0',
        );
      }
      for (final item in conversations) {
        await _upsertConversation(item);
      }

      for (final item in messages) {
        await _upsertMessage(item);
      }

      for (final item in models) {
        await customInsert(
          '''
            INSERT INTO cached_models (
              id, alias, upstream_model, enabled, is_default, default_temperature, default_max_tokens, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              alias = excluded.alias,
              upstream_model = excluded.upstream_model,
              enabled = excluded.enabled,
              is_default = excluded.is_default,
              default_temperature = excluded.default_temperature,
              default_max_tokens = excluded.default_max_tokens,
              updated_at = excluded.updated_at
          ''',
          variables: [
            Variable.withString(item['id'] as String),
            Variable.withString(item['alias'] as String),
            Variable.withString(item['upstream_model'] as String),
            Variable.withBool(item['enabled'] as bool? ?? true),
            Variable.withBool(item['is_default'] as bool? ?? false),
            Variable.withReal(
              (item['default_temperature'] as num?)?.toDouble() ?? 0.6,
            ),
            Variable.withInt(
              (item['default_max_tokens'] as num?)?.toInt() ?? 1200,
            ),
            Variable.withString(item['updated_at'] as String),
          ],
        );
      }

      for (final item in personas) {
        await customInsert(
          '''
            INSERT INTO cached_personas (
              id, name, description, system_prompt, default_model_alias, temperature, enabled, is_default, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              description = excluded.description,
              system_prompt = excluded.system_prompt,
              default_model_alias = excluded.default_model_alias,
              temperature = excluded.temperature,
              enabled = excluded.enabled,
              is_default = excluded.is_default,
              updated_at = excluded.updated_at
          ''',
          variables: [
            Variable.withString(item['id'] as String),
            Variable.withString(item['name'] as String),
            Variable.withString(item['description'] as String? ?? ''),
            Variable.withString(item['system_prompt'] as String? ?? ''),
            Variable<String>(item['default_model_alias'] as String?),
            Variable.withReal((item['temperature'] as num?)?.toDouble() ?? 0.6),
            Variable.withBool(item['enabled'] as bool? ?? true),
            Variable.withBool(item['is_default'] as bool? ?? false),
            Variable.withString(item['updated_at'] as String),
          ],
        );
      }
    });

    notifyUpdates({
      const TableUpdate('chat_sessions'),
      const TableUpdate('chat_messages'),
      const TableUpdate('cached_models'),
      const TableUpdate('cached_personas'),
    });
  }

  Future<List<ChatSession>> _fetchSessions() async {
    final rows = await customSelect('''
        SELECT *
        FROM chat_sessions
        WHERE deleted_at IS NULL
        ORDER BY updated_at DESC
      ''').get();
    return rows.map(ChatSession.fromRow).toList();
  }

  Future<List<ChatMessage>> _fetchMessages(String conversationId) async {
    final rows = await customSelect(
      '''
        SELECT *
        FROM chat_messages
        WHERE conversation_id = ? AND deleted_at IS NULL AND id NOT LIKE 'local-%'
        ORDER BY created_at ASC
      ''',
      variables: [Variable.withString(conversationId)],
    ).get();
    return rows.map(ChatMessage.fromRow).toList();
  }

  Future<void> _upsertConversation(Map<String, dynamic> item) async {
    await customInsert(
      '''
        INSERT INTO chat_sessions (
          id, title, user_id, model_alias, persona_id, last_message_preview, created_at, updated_at, deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          user_id = excluded.user_id,
          model_alias = excluded.model_alias,
          persona_id = excluded.persona_id,
          last_message_preview = excluded.last_message_preview,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at
      ''',
      variables: [
        Variable.withString(item['id'] as String),
        Variable.withString(item['title'] as String? ?? 'New chat'),
        Variable.withString(item['user_id'] as String? ?? ''),
        Variable<String>(item['model_alias'] as String?),
        Variable<String>(item['persona_id'] as String?),
        Variable.withString(item['last_message_preview'] as String? ?? ''),
        Variable.withString(item['created_at'] as String),
        Variable.withString(item['updated_at'] as String),
        Variable<String>(item['deleted_at'] as String?),
      ],
    );
  }

  Future<void> _upsertMessage(Map<String, dynamic> item) async {
    await customInsert(
      '''
        INSERT INTO chat_messages (
          id, conversation_id, user_id, role, content, model_alias, upstream_model, status, local_image_paths, attachments, created_at, updated_at, deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          conversation_id = excluded.conversation_id,
          user_id = excluded.user_id,
          role = excluded.role,
          content = excluded.content,
          model_alias = excluded.model_alias,
          upstream_model = excluded.upstream_model,
          status = excluded.status,
          local_image_paths = coalesce(excluded.local_image_paths, chat_messages.local_image_paths),
          attachments = coalesce(excluded.attachments, chat_messages.attachments),
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at
      ''',
      variables: [
        Variable.withString(item['id'] as String),
        Variable.withString(item['conversation_id'] as String),
        Variable<String>(item['user_id'] as String?),
        Variable.withString(item['role'] as String? ?? 'assistant'),
        Variable.withString(item['content'] as String? ?? ''),
        Variable<String>(item['model_alias'] as String?),
        Variable<String>(item['upstream_model'] as String?),
        Variable.withString(item['status'] as String? ?? 'complete'),
        Variable<String>(item['local_image_paths'] as String?),
        Variable<String>(
          item['attachments'] == null ? null : jsonEncode(item['attachments']),
        ),
        Variable.withString(item['created_at'] as String),
        Variable.withString(item['updated_at'] as String),
        Variable<String>(item['deleted_at'] as String?),
      ],
    );
  }
}

List<String> decodeLocalImagePaths(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw.split('\n').where((item) => item.isNotEmpty).toList();
}

List<Map<String, dynamic>> decodeAttachments(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'shinokawa_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
