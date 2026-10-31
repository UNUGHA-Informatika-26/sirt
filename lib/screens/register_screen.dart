import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_colors.dart';
import '../utils/app_error.dart';
import '../widgets/form_widgets.dart';

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
  final _passwordConfirmation = TextEditingController();
  bool _hidePassword = true;
  bool _hidePasswordConfirmation = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nik.dispose();
    _phone.dispose();
    _address.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
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
      }
      Navigator.pop(context);
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
                  padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
                  children: [
                    const Text('Buat akun warga',
                        style: TextStyle(
                            color: appInk,
                            fontSize: 25,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Isi data untuk mendaftar di lingkungan RT.',
                        style: TextStyle(color: appMuted, fontSize: 13)),
                    const SizedBox(height: 14),
                    _formField('Nama lengkap', 'Nama sesuai KTP', _name),
                    _formField('NIK', '16 digit', _nik,
                        keyboardType: TextInputType.number,
                        maxLength: 16,
                        validator: (value) => value == null || value.length != 16
                            ? 'NIK harus terdiri dari 16 digit'
                            : null),
                    _formField('Nomor HP', '08xxxxxxxxxx', _phone,
                        keyboardType: TextInputType.phone),
                    _formField(
                        'Alamat', 'Alamat rumah di lingkungan RT', _address),
                    _formField('Email', 'nama@email.com', _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || !value.contains('@')
                                ? 'Masukkan alamat email yang valid'
                                : null),
                    _formField('Kata sandi', 'Minimal 8 karakter', _password,
                        obscureText: _hidePassword,
                        suffix: IconButton(
                          tooltip: _hidePassword
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Kata sandi minimal 8 karakter'
                            : null),
                    _formField(
                      'Konfirmasi kata sandi',
                      'Ulangi kata sandi',
                      _passwordConfirmation,
                      obscureText: _hidePasswordConfirmation,
                      suffix: IconButton(
                        tooltip: _hidePasswordConfirmation
                            ? 'Tampilkan konfirmasi kata sandi'
                            : 'Sembunyikan konfirmasi kata sandi',
                        onPressed: () => setState(() =>
                            _hidePasswordConfirmation =
                                !_hidePasswordConfirmation),
                        icon: Icon(_hidePasswordConfirmation
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                      ),
                      validator: (value) => value != _password.text
                          ? 'Konfirmasi kata sandi belum sama'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: _busy ? 'Membuat akun...' : 'Buat akun warga',
                      onPressed: _busy ? null : _register,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: appGreen,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Sudah terdaftar? Masuk'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _formField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int? maxLength,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(label),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              obscureText: obscureText,
              validator: validator ?? _required,
              decoration: inputDecoration(hint)
                  .copyWith(counterText: '', suffixIcon: suffix),
            ),
          ],
        ),
      );
}
