import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_theme.dart';
import 'data/api_client.dart';
import 'data/app_database.dart';
import 'data/auth_store.dart';
import 'models/app_models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final authStore = await AuthStore.create();
  runApp(
    ShinokawaChatApp(
      database: database,
      authStore: authStore,
      apiClient: ApiClient(),
    ),
  );
}

class ShinokawaChatApp extends StatefulWidget {
  const ShinokawaChatApp({
    super.key,
    required this.database,
    required this.authStore,
    required this.apiClient,
  });

  final AppDatabase database;
  final AuthStore authStore;
  final ApiClient apiClient;

  @override
  State<ShinokawaChatApp> createState() => _ShinokawaChatAppState();
}

class _ShinokawaChatAppState extends State<ShinokawaChatApp> {
  AuthSession? _session;
  late ThemeMode _themeMode;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _session = widget.authStore.loadSession();
    _themeMode = widget.authStore.loadThemeMode();
    _locale = widget.authStore.loadLocale();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();
    return MaterialApp(
      title: 'ShinoChat',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: _themeMode,
      theme: buildAppTheme(textTheme, Brightness.light),
      darkTheme: buildAppTheme(textTheme, Brightness.dark),
      home: _session == null
          ? LoginScreen(
              authStore: widget.authStore,
              apiClient: widget.apiClient,
              onLoggedIn: (session) async {
                if (_session?.username != session.username) {
                  await widget.database.clearUserData();
                }
                if (mounted) {
                  setState(() => _session = session);
                }
              },
            )
          : HomeScreen(
              database: widget.database,
              authStore: widget.authStore,
              apiClient: widget.apiClient,
              session: _session!,
              themeMode: _themeMode,
              onSessionChanged: (session) async {
                await widget.authStore.saveSession(session);
                if (mounted) {
                  setState(() => _session = session);
                }
              },
              onLocaleChanged: (locale) async {
                await widget.authStore.saveLocale(locale);
                if (mounted) {
                  setState(() => _locale = locale);
                }
              },
              onThemeModeChanged: (mode) async {
                await widget.authStore.saveThemeMode(mode);
                if (mounted) {
                  setState(() => _themeMode = mode);
                }
              },
              onLoggedOut: () async {
                await widget.authStore.clear();
                await widget.database.clearUserData();
                if (mounted) {
                  setState(() => _session = null);
                }
              },
            ),
    );
  }
}
