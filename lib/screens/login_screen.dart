import 'package:flutter/material.dart';

import '../core/app_locale.dart';
import '../data/api_client.dart';
import '../data/auth_store.dart';
import '../models/app_models.dart';
import '../widgets/shino_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authStore,
    required this.apiClient,
    required this.onLoggedIn,
  });

  final AuthStore authStore;
  final ApiClient apiClient;
  final ValueChanged<AuthSession> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController(
    text: 'https://chat.shinokawa.top',
  );
  final _usernameController = TextEditingController(text: 'Yi');
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await widget.apiClient.login(
        baseUrl: _baseUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await widget.authStore.saveSession(session);
      widget.onLoggedIn(session);
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF111111), Color(0xFF1A1A1D)]
                : const [Color(0xFFFFF4F8), Color(0xFFFFE3EE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShinoMark(size: 52),
                          const SizedBox(height: 18),
                          Text(
                            '欢迎使用Sakiko喵🥰',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFBFC1C9)
                                  : const Color(0xFF69756F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ShinoChat',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _baseUrlController,
                            decoration: InputDecoration(
                              labelText: appText(
                                context,
                                zh: '服务器地址',
                                en: 'Server URL',
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? appText(
                                    context,
                                    zh: '请输入服务器地址',
                                    en: 'Enter server URL',
                                  )
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: appText(
                                context,
                                zh: '用户名',
                                en: 'Username',
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? appText(
                                    context,
                                    zh: '请输入用户名',
                                    en: 'Enter username',
                                  )
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: appText(
                                context,
                                zh: '密码',
                                en: 'Password',
                              ),
                            ),
                            obscureText: true,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? appText(
                                    context,
                                    zh: '请输入密码',
                                    en: 'Enter password',
                                  )
                                : null,
                          ),
                          const SizedBox(height: 18),
                          if (_error != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: isDark
                                    ? const Color(0x33B6786A)
                                    : const Color(0x24B6786A),
                              ),
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF9B5248),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                _submitting
                                    ? appText(
                                        context,
                                        zh: '登录中...',
                                        en: 'Signing in...',
                                      )
                                    : appText(
                                        context,
                                        zh: '进入应用',
                                        en: 'Enter app',
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
