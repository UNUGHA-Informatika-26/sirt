import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_colors.dart';
import '../utils/app_error.dart';
import '../widgets/form_widgets.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const PasswordRecoveryScreen({required this.onCompleted, super.key});

  @override
  State<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      await auth.updateUser(UserAttributes(password: _password.text));
      try {
        await auth.signOut(scope: SignOutScope.global);
      } catch (_) {
        await auth.signOut();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi berhasil diubah. Silakan masuk kembali.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onCompleted();
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
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 32),
                  children: [
                    const Icon(Icons.lock_reset_outlined,
                        color: appGreen, size: 54),
                    const SizedBox(height: 22),
                    const Text(
                      'Buat kata sandi baru',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appInk,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gunakan minimal 8 karakter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    const FieldLabel('Kata sandi baru'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: inputDecoration('Minimal 8 karakter').copyWith(
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 8
                          ? 'Kata sandi minimal 8 karakter'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Ulangi kata sandi baru'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: _hidePassword,
                      decoration: inputDecoration('Ulangi kata sandi'),
                      validator: (value) => value != _password.text
                          ? 'Kata sandi belum sama'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: _busy ? 'Menyimpan...' : 'Simpan kata sandi baru',
                      onPressed: _busy ? null : _savePassword,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
