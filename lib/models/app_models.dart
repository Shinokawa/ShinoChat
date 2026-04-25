class AuthSession {
  const AuthSession({
    required this.baseUrl,
    required this.token,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
  });

  final String baseUrl;
  final String token;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String role;

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'token': token,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    baseUrl: json['baseUrl'] as String,
    token: json['token'] as String,
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String? ?? '',
    role: json['role'] as String,
  );

  factory AuthSession.fromApi({
    required String baseUrl,
    required String token,
    required Map<String, dynamic> user,
  }) => AuthSession(
    baseUrl: baseUrl,
    token: token,
    username: user['username'] as String,
    displayName: user['display_name'] as String? ?? user['username'] as String,
    avatarUrl: user['avatar_url'] as String? ?? '',
    role: user['role'] as String,
  );

  AuthSession copyWith({
    String? baseUrl,
    String? token,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? role,
  }) => AuthSession(
    baseUrl: baseUrl ?? this.baseUrl,
    token: token ?? this.token,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    role: role ?? this.role,
  );
}

class ChatStreamEvent {
  const ChatStreamEvent({required this.type, required this.payload});

  final String type;
  final Map<String, dynamic> payload;
}

class SyncPayload {
  const SyncPayload({
    required this.serverTime,
    required this.conversations,
    required this.messages,
    required this.models,
    required this.personas,
  });

  final String serverTime;
  final List<Map<String, dynamic>> conversations;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> models;
  final List<Map<String, dynamic>> personas;

  factory SyncPayload.fromJson(Map<String, dynamic> json) => SyncPayload(
    serverTime: json['server_time'] as String,
    conversations: List<Map<String, dynamic>>.from(
      json['conversations'] as List<dynamic>? ?? const [],
    ),
    messages: List<Map<String, dynamic>>.from(
      json['messages'] as List<dynamic>? ?? const [],
    ),
    models: List<Map<String, dynamic>>.from(
      json['models'] as List<dynamic>? ?? const [],
    ),
    personas: List<Map<String, dynamic>>.from(
      json['personas'] as List<dynamic>? ?? const [],
    ),
  );
}
