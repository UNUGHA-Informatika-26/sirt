import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../utils/app_error.dart';
import '../widgets/form_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

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
      _message(friendlyError(error));
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
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 72, 10, 32),
                children: [
                  const SirtLogo(size: 56, showName: false),
                  const SizedBox(height: 24),
                  const Text('Masuk ke SiRT',
                      style: TextStyle(
                          color: appInk,
                          fontSize: 26,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  const Text('Layanan warga dalam satu aplikasi.',
                      style: TextStyle(color: appMuted, fontSize: 14)),
                  const SizedBox(height: 36),
                  const FieldLabel('Email'),
                  const SizedBox(height: 5),
                  InputField(
                    controller: _email,
                    hint: 'nama@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  const FieldLabel('Kata sandi'),
                  const SizedBox(height: 5),
                  InputField(
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
                        color: appMuted,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail: _email.text.trim(),
                                  ),
                                ),
                              ),
                      style: TextButton.styleFrom(
                        foregroundColor: appGreen,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: _busy ? 'Memproses...' : 'Masuk',
                    onPressed: _busy ? null : _login,
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum punya akun?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appMuted, fontSize: 13)),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                    style: TextButton.styleFrom(
                      foregroundColor: appGreen,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Daftar sebagai warga'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
