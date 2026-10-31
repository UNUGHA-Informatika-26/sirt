import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_colors.dart';
import '../utils/app_error.dart';
import '../widgets/form_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({this.initialEmail = '', super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  bool _busy = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _message('Masukkan alamat email yang valid.');
      return;
    }

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (mounted) setState(() => _sent = true);
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
        appBar: AppBar(
          title: const Text('Lupa kata sandi'),
          backgroundColor: appBackground,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 42, 24, 30),
                children: [
                  const Icon(Icons.lock_reset_outlined,
                      color: appGreen, size: 52),
                  const SizedBox(height: 20),
                  Text(
                    _sent ? 'Cek email kamu' : 'Atur ulang kata sandi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: appInk,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sent
                        ? 'Jika email terdaftar, tautan reset sudah dikirim. Buka tautan itu di browser yang sama untuk membuat kata sandi baru.'
                        : 'Masukkan email akun SiRT. Kami akan mengirim tautan untuk membuat kata sandi baru.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: appMuted, fontSize: 14),
                  ),
                  if (!_sent) ...[
                    const SizedBox(height: 30),
                    const FieldLabel('Email'),
                    const SizedBox(height: 6),
                    InputField(
                      controller: _email,
                      hint: 'nama@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: _busy ? 'Mengirim...' : 'Kirim tautan reset',
                      onPressed: _busy ? null : _sendResetEmail,
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _busy ? null : () => setState(() => _sent = false),
                      child: const Text('Kirim ulang'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
