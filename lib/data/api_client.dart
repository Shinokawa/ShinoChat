import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    return AuthSession.fromApi(
      baseUrl: baseUrl,
      token: data['access_token'] as String,
      user: user,
    );
  }

  Future<AuthSession> updateProfile(
    AuthSession session, {
    String? username,
    String? displayName,
    String? avatarUrl,
    String? password,
  }) async {
    final body = {
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'password': password,
    }..removeWhere((_, value) => value == null);
    final response = await _client.patch(
      Uri.parse('${session.baseUrl}/api/auth/me'),
      headers: _headers(session.token),
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromApi(
      baseUrl: session.baseUrl,
      token: data['access_token'] as String? ?? session.token,
      user: data['user'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> bootstrap(AuthSession session) async {
    final response = await _client.get(
      Uri.parse('${session.baseUrl}/api/bootstrap'),
      headers: _headers(session.token),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<SyncPayload> sync(AuthSession session, {String? since}) async {
    final uri = Uri.parse('${session.baseUrl}/api/sync').replace(
      queryParameters: since == null || since.isEmpty ? null : {'since': since},
    );
    final response = await _client.get(uri, headers: _headers(session.token));
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
    return SyncPayload.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Uint8List> fetchAttachment(AuthSession session, String sha256) async {
    final response = await _client.get(
      Uri.parse('${session.baseUrl}/api/attachments/$sha256'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
    return response.bodyBytes;
  }

  Future<void> deleteConversation(
    AuthSession session,
    String conversationId,
  ) async {
    final response = await _client.delete(
      Uri.parse('${session.baseUrl}/api/sessions/$conversationId'),
      headers: _headers(session.token),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
  }

  Future<void> updateConversation(
    AuthSession session,
    String conversationId, {
    String? title,
    String? modelAlias,
    String? personaId,
  }) async {
    final response = await _client.patch(
      Uri.parse('${session.baseUrl}/api/sessions/$conversationId'),
      headers: _headers(session.token),
      body: jsonEncode(
        {'title': title, 'model_alias': modelAlias, 'persona_id': personaId}
          ..removeWhere((_, value) => value == null),
      ),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
  }

  Future<Map<String, dynamic>> createConversation(
    AuthSession session, {
    String title = 'New chat',
    String? modelAlias,
    String? personaId,
  }) async {
    final response = await _client.post(
      Uri.parse('${session.baseUrl}/api/sessions'),
      headers: _headers(session.token),
      body: jsonEncode(
        {'title': title, 'model_alias': modelAlias, 'persona_id': personaId}
          ..removeWhere((_, value) => value == null),
      ),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractError(response.body, response.reasonPhrase));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Stream<ChatStreamEvent> streamChat({
    required AuthSession session,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
    String? conversationId,
    String? modelAlias,
    String? personaId,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${session.baseUrl}/api/chat/stream'),
    );
    request.headers.addAll(_headers(session.token));
    request.body = jsonEncode(
      {
        'conversation_id': conversationId,
        'content': content,
        'attachments': attachments
            .map(
              (item) =>
                  Map<String, dynamic>.from(item)
                    ..removeWhere((key, _) => key == 'local_path'),
            )
            .toList(),
        'model_alias': modelAlias,
        'persona_id': personaId,
      }..removeWhere((_, value) => value == null),
    );
    final response = await _client.send(request);
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw Exception(_extractError(body, response.reasonPhrase));
    }

    String? currentEvent;
    final lines = response.stream
        .asBroadcastStream()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        final payload =
            jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
        yield ChatStreamEvent(
          type: currentEvent ?? 'message',
          payload: payload,
        );
        currentEvent = null;
      }
    }
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  String _extractError(String body, String? fallback) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['detail'] as String? ?? fallback ?? 'Request failed';
    } catch (_) {
      return fallback ?? body;
    }
  }
}
