import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/admin_residents_controller.dart';
import '../widgets/form_widgets.dart';

class AdminResidentsScreen extends StatefulWidget {
  const AdminResidentsScreen({super.key});

  @override
  State<AdminResidentsScreen> createState() => _AdminResidentsScreenState();
}

class _AdminResidentsScreenState extends State<AdminResidentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _addressController = TextEditingController();
  late final AdminResidentsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminResidentsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _nikController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveResident() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await _controller.addResident(
        name: _nameController.text,
        nik: _nikController.text,
        address: _addressController.text,
      );
      if (!mounted) return;
      _nameController.clear();
      _nikController.clear();
      _addressController.clear();
      _formKey.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data warga tersimpan di Supabase.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data warga gagal disimpan: $error')),
      );
    }
  }

  Future<void> _deleteResident(ResidentRecord resident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus data warga?'),
        content: Text(resident.isAccount
            ? 'Akun ${resident.name} dan profil Supabase-nya akan dihapus permanen. Pengguna tersebut tidak dapat login lagi.'
            : 'Data ${resident.name} akan dihapus permanen dari daftar warga.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (resident.isAccount) {
        await _controller.deleteRegisteredResident(resident.id);
      } else {
        await _controller.deleteResident(resident.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resident.isAccount
            ? 'Akun warga dihapus permanen dari Supabase.'
            : 'Data warga dihapus permanen.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data warga gagal dihapus: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                children: [
                  const Text(
                    'Tambah Warga',
                    style: TextStyle(
                        color: appInk,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Tambahkan data warga ke lingkungan RT.',
                    style: TextStyle(color: appMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  _compactField(
                    controller: _nameController,
                    hint: 'Nama',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 5),
                  _compactField(
                    controller: _nikController,
                    hint: 'Nomor Induk Kependudukan (NIK)',
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    validator: (value) => value == null || value.length != 16
                        ? 'NIK harus terdiri dari 16 digit'
                        : null,
                  ),
                  const SizedBox(height: 5),
                  _compactField(
                    controller: _addressController,
                    hint: 'Alamat',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Alamat wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 38,
                    child: FilledButton(
                      onPressed: _controller.isSaving ? null : _saveResident,
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                      child: _controller.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan data warga'),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'DATA WARGA',
                    style: TextStyle(
                        color: appInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  if (_controller.error != null)
                    _EmptyResidents(
                        message: 'Data warga gagal dimuat. Periksa koneksi dan hak akses admin.'),
                  if (_controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: CircularProgressIndicator(color: appGreen)),
                    ),
                  if (!_controller.isLoading && _controller.error == null) ...[
                    const _SectionCaption(label: 'AKUN WARGA TERDAFTAR'),
                    if (_controller.registeredResidents.isEmpty)
                      const _EmptyResidents(
                          message: 'Belum ada akun warga terdaftar.'),
                    for (final resident in _controller.registeredResidents) ...[
                      _ResidentCard(
                        resident: resident,
                        deleting: _controller.isDeleting(resident.id),
                        onDelete: () => _deleteResident(resident),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 10),
                    const _SectionCaption(label: 'DATA WARGA TAMBAHAN'),
                    if (_controller.residents.isEmpty)
                      const _EmptyResidents(
                          message: 'Belum ada data warga tambahan.'),
                  ],
                  if (!_controller.isLoading && _controller.error == null)
                    for (final resident in _controller.residents) ...[
                      _ResidentCard(
                        resident: resident,
                        deleting: _controller.isDeleting(resident.id),
                        onDelete: () => _deleteResident(resident),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _compactField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int? maxLength,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        validator: validator,
        style: const TextStyle(color: appInk, fontSize: 11),
        decoration: inputDecoration(hint).copyWith(
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          isDense: true,
          filled: true,
        ),
      );
}

class _ResidentCard extends StatelessWidget {
  final ResidentRecord resident;
  final VoidCallback? onDelete;
  final bool deleting;

  const _ResidentCard({
    required this.resident,
    this.onDelete,
    required this.deleting,
  });

  @override
  Widget build(BuildContext context) {
    final firstLetter = resident.name.trim().isEmpty
        ? '?'
        : resident.name.trim().substring(0, 1).toUpperCase();
    return Container(
      constraints: const BoxConstraints(minHeight: 57),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: appBorder),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFE5F3EF),
            child: Text(firstLetter,
                style: const TextStyle(
                    color: appGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${resident.name} · ${resident.nik}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: appInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(resident.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: appMuted, fontSize: 9)),
              ],
            ),
          ),
          IconButton(
            tooltip: onDelete == null ? 'Akun warga terdaftar' : 'Hapus warga',
            visualDensity: VisualDensity.compact,
            onPressed: deleting ? null : onDelete,
            icon: deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, size: 18, color: appInk),
          ),
        ],
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  final String label;
  const _SectionCaption({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          label,
          style: const TextStyle(
              color: appInk, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
}

class _EmptyResidents extends StatelessWidget {
  final String message;
  const _EmptyResidents({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(message,
            style: const TextStyle(color: appMuted, fontSize: 10)),
      );
}
