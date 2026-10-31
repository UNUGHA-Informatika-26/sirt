import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';
import 'screens/admin_home_screen.dart';
import 'screens/citizen_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/password_recovery_screen.dart';
import 'supabase_config.dart';
import 'utils/app_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const SiRTApp());
}

class SiRTApp extends StatelessWidget {
  const SiRTApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SiRT',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: appBackground,
          colorScheme: ColorScheme.fromSeed(seedColor: appGreen),
        ),
        home: const AppRouter(),
      );
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _session;
  bool _recoveryFlow = false;
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _recoveryFlow = _hasRecoveryTypeInUrl();
    _splashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showSplash = false);
    });
    _authSubscription = auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() {
        _session = state.session;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _recoveryFlow = true;
        }
      });
    });
  }

  bool _hasRecoveryTypeInUrl() {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    if (uri.queryParameters['type'] == 'recovery') return true;
    try {
      return Uri.splitQueryString(uri.fragment)['type'] == 'recovery';
    } on FormatException {
      return false;
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const _SirtSplashScreen();

    if (_recoveryFlow) {
      return PasswordRecoveryScreen(
        onCompleted: () {
          if (mounted) setState(() => _recoveryFlow = false);
        },
      );
    }

    final session = _session;
    if (session == null) return const LoginScreen();

    return FutureBuilder<String>(
      key: ValueKey(session.user.id),
      future: _loadRole(session.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: appGreen)),
          );
        }
        if (snapshot.hasError) {
          return _RoleErrorScreen(message: friendlyError(snapshot.error!));
        }
        if (snapshot.data == 'admin') return const AdminHomeScreen();
        return const CitizenHomeScreen();
      },
    );
  }

  Future<String> _loadRole(String userId) async {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    return row['role'] as String? ?? 'warga';
  }
}

class _RoleErrorScreen extends StatelessWidget {
  final String message;
  const _RoleErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: appGreen, size: 48),
              const SizedBox(height: 12),
              const Text('Profil akun belum siap',
                  style: TextStyle(
                      color: appInk, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: appMuted)),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Keluar'),
              ),
            ]),
          ),
        ),
      );
}


class _SirtSplashScreen extends StatelessWidget {
  const _SirtSplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/images/sirt_logo.png',
                  width: 176,
                  height: 176,
                  fit: BoxFit.cover,
                  semanticLabel: 'Logo SiRT',
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Sistem Manajemen RT',
                style: TextStyle(
                  color: appInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 26),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: appGreen,
                ),
              ),
            ],
          ),
        ),
      );
}
