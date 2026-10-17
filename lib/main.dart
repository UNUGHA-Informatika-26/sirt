import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _background = Color(0xFFF5F8F7);
const Color _green = Color(0xFF07836D);
const Color _ink = Color(0xFF1B2926);
const Color _muted = Color(0xFF82918D);
const Color _border = Color(0xFFE0E9E6);
const String _supabaseUrl = 'https://wwpyjjhgexjbszlepwbe.supabase.co';
const String _supabasePublishableKey = 'sb_publishable_hl3i6wsz_ZYe1NeQtj760w_mz7vLGae';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabasePublishableKey.isEmpty || _supabasePublishableKey == 'GANTI_DENGAN_PUBLISHABLE_KEY') {
    runApp(const ConfigurationApp());
    return;
  }
  await Supabase.initialize(
      url: _supabaseUrl, publishableKey: _supabasePublishableKey);
  runApp(const SiRTApp());
}

class ConfigurationApp extends StatelessWidget {
  const ConfigurationApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: _background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: const Text(
                  'Konfigurasi Supabase belum diisi. Jalankan aplikasi dengan '
                  'menempelkan publishable key proyek ke konstanta '
                  '_supabasePublishableKey di lib/main.dart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ink, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );
}

class SiRTApp extends StatelessWidget {
  const SiRTApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SiRT',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _background,
          colorScheme: ColorScheme.fromSeed(seedColor: _green),
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
  late final Stream<AuthState> _authChanges;
  Session? _session;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _authChanges = auth.onAuthStateChange;
    _authChanges.listen((state) {
      if (mounted) setState(() => _session = state.session);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const LoginScreen();
    return FutureBuilder<String>(
      key: ValueKey(session.user.id),
      future: _loadRole(session.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _green)),
          );
        }
        if (snapshot.hasError) {
          return _RoleErrorScreen(message: _friendlyError(snapshot.error!));
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _message('Isi email dan kata sandi terlebih dahulu.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      _message(error.message);
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 72, 10, 32),
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: _green, shape: BoxShape.circle),
                  child: const Icon(Icons.home_outlined,
                      color: Colors.white, size: 27),
                ),
                const SizedBox(height: 24),
                const Text('Masuk ke SiRT',
                    style: TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                const Text('Layanan warga dalam satu aplikasi.',
                    style: TextStyle(color: _muted, fontSize: 14)),
                const SizedBox(height: 36),
                const _FieldLabel('Email'),
                const SizedBox(height: 5),
                _InputField(
                    controller: _email,
                    hint: 'nama@email.com',
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                const _FieldLabel('Kata sandi'),
                const SizedBox(height: 5),
                _InputField(
                  controller: _password,
                  hint: 'Kata sandi',
                  obscureText: _hidePassword,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: _muted,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _PrimaryButton(
                  label: _busy ? 'Memproses...' : 'Masuk',
                  onPressed: _busy ? null : _login,
                ),
                const SizedBox(height: 16),
                const Text('Belum punya akun?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 13)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                  style: TextButton.styleFrom(
                      foregroundColor: _green,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  child: const Text('Daftar sebagai warga'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nik = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nik.dispose();
    _phone.dispose();
    _address.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi' : null;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'full_name': _name.text.trim(),
          'nik': _nik.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
        },
      );
      if (!mounted) return;
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Akun berhasil dibuat. Cek email untuk verifikasi, lalu masuk.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
                children: [
                  const Text('Buat akun warga',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 25,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Isi data untuk mendaftar di lingkungan RT.',
                      style: TextStyle(color: _muted, fontSize: 13)),
                  const SizedBox(height: 14),
                  _formField('Nama lengkap', 'Nama sesuai KTP', _name),
                  _formField('NIK', '16 digit', _nik,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      validator: (v) => v == null || v.length != 16
                          ? 'NIK harus terdiri dari 16 digit'
                          : null),
                  _formField('Nomor HP', '08xxxxxxxxxx', _phone,
                      keyboardType: TextInputType.phone),
                  _formField(
                      'Alamat', 'Alamat rumah di lingkungan RT', _address),
                  _formField('Email', 'nama@email.com', _email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Masukkan alamat email yang valid'
                          : null),
                  _formField('Kata sandi', 'Minimal 8 karakter', _password,
                      obscureText: true,
                      validator: (v) => v == null || v.length < 8
                          ? 'Kata sandi minimal 8 karakter'
                          : null),
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: _busy ? 'Membuat akun...' : 'Buat akun warga',
                    onPressed: _busy ? null : _register,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        foregroundColor: _green,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    child: const Text('Sudah terdaftar? Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int? maxLength,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            obscureText: obscureText,
            validator: validator ?? _required,
            decoration: _inputDecoration(hint).copyWith(counterText: ''),
          ),
        ],
      ),
    );
  }
}

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => _LandingScreen(
        title: 'Beranda warga',
        subtitle: 'Login berhasil sebagai warga.',
        icon: Icons.home_outlined,
      );
}

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => _LandingScreen(
        title: 'Halaman admin',
        subtitle: 'Login berhasil sebagai admin.',
        icon: Icons.admin_panel_settings_outlined,
      );
}

class _LandingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _LandingScreen(
      {required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('SiRT'),
          backgroundColor: _background,
          actions: [
            IconButton(
              tooltip: 'Keluar',
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            )
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: _green, size: 56),
                const SizedBox(height: 18),
                Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: _muted)),
              ],
            ),
          ),
        ),
      );
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
              const Icon(Icons.error_outline, color: _green, size: 48),
              const SizedBox(height: 12),
              const Text('Profil akun belum siap',
                  style: TextStyle(
                      color: _ink, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted)),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFF71817C),
            fontSize: 12,
            fontWeight: FontWeight.w600),
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: _inputDecoration(hint).copyWith(suffixIcon: suffix),
      );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _green, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    );

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      );
}

String _friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('profiles') || text.contains('PGRST')) {
    return 'Tabel profiles belum dibuat. Jalankan SQL setup SiRT di Supabase.';
  }
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Tidak bisa tersambung. Periksa internet dan URL Supabase.';
  }
  return text;
}


