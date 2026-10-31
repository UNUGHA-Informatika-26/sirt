import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/citizen_request_service.dart';
import '../utils/app_error.dart';
import '../widgets/decision_document_button.dart';

class CitizenServiceRequestsScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const CitizenServiceRequestsScreen({required this.onNavigateTab, super.key});

  @override
  State<CitizenServiceRequestsScreen> createState() =>
      _CitizenServiceRequestsScreenState();
}

class _CitizenServiceRequestsScreenState
    extends State<CitizenServiceRequestsScreen> {
  late final Stream<List<CitizenRequest>> _requests;

  @override
  void initState() {
    super.initState();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _requests = userId == null
        ? Stream<List<CitizenRequest>>.value(const [])
        : CitizenRequestService.watchMine(userId);
  }

  void _navigateTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onNavigateTab(index);
  }

  Future<void> _openForm(String type) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _CitizenRequestForm(type: type)),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan dikirim dan menunggu persetujuan admin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          titleSpacing: 20,
          title: const SirtLogo(),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 18),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE5F3EF),
                child: Icon(Icons.person, color: appGreen, size: 16),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: StreamBuilder<List<CitizenRequest>>(
                stream: _requests,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _RequestNotice(
                        text: 'Pengajuan tidak dapat dimuat: ${friendlyError(snapshot.error!)}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: appGreen));
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
                    children: [
                      const Text('Pengajuan',
                          style: TextStyle(
                              color: appInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      const Text('Ajukan layanan dan pantau hasilnya di sini.',
                          style: TextStyle(color: appMuted, fontSize: 10)),
                      const SizedBox(height: 14),
                      _RequestActionButton(
                        label: 'Ajukan surat baru',
                        icon: Icons.add,
                        onPressed: () => _openForm('letter'),
                      ),
                      const SizedBox(height: 7),
                      _RequestActionButton(
                        label: 'Ajukan laporan tamu',
                        icon: Icons.add,
                        onPressed: () => _openForm('guest'),
                      ),
                      const SizedBox(height: 19),
                      const Text('Riwayat pengajuan dan pelaporan',
                          style: TextStyle(
                              color: appInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (snapshot.data!.isEmpty)
                        const _RequestNotice(
                            text: 'Belum ada pengajuan. Pengajuan yang kamu kirim akan tampil di sini.'),
                      for (final request in snapshot.data!) ...[
                        _CitizenRequestCard(request: request),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE5F3EF),
          selectedIndex: 1,
          onDestinationSelected: _navigateTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'Layanan'),
            NavigationDestination(icon: Icon(Icons.access_time_outlined), label: 'Jadwal'),
            NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
          ],
        ),
      );
}

class _CitizenRequestForm extends StatefulWidget {
  final String type;
  const _CitizenRequestForm({required this.type});

  @override
  State<_CitizenRequestForm> createState() => _CitizenRequestFormState();
}

class _CitizenRequestFormState extends State<_CitizenRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _residentName = TextEditingController();
  final _letterPurpose = TextEditingController();
  final _letterName = TextEditingController();
  final _guestName = TextEditingController();
  final _guestOrigin = TextEditingController();
  final _guestPurpose = TextEditingController();
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _sending = false;

  bool get _isLetter => widget.type == 'letter';

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _residentName.text = user?.userMetadata?['full_name']?.toString() ?? '';
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 1);
    _endsAt = _startsAt.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _residentName.dispose();
    _letterPurpose.dispose();
    _letterName.dispose();
    _guestName.dispose();
    _guestOrigin.dispose();
    _guestPurpose.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi' : null;

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _chooseTime({required bool start}) async {
    final picked = await _pickDateTime(start ? _startsAt : _endsAt);
    if (picked == null) return;
    setState(() {
      if (start) {
        _startsAt = picked;
        if (!_endsAt.isAfter(picked)) {
          _endsAt = picked.add(const Duration(hours: 1));
        }
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLetter) {
      final duration = _endsAt.difference(_startsAt);
      if (duration <= Duration.zero || duration > const Duration(hours: 24)) {
        _message('Waktu laporan tamu harus lebih dari 0 dan maksimal 24 jam.');
        return;
      }
    }
    setState(() => _sending = true);
    try {
      final data = _isLetter
          ? <String, dynamic>{
              'applicant_name': _residentName.text.trim(),
              'purpose': _letterPurpose.text.trim(),
              'letter_name': _letterName.text.trim(),
            }
          : <String, dynamic>{
              'guest_name': _guestName.text.trim(),
              'guest_origin': _guestOrigin.text.trim(),
              'purpose': _guestPurpose.text.trim(),
              'starts_at': _startsAt.toUtc().toIso8601String(),
              'ends_at': _endsAt.toUtc().toIso8601String(),
            };
      await CitizenRequestService.submit(
        type: widget.type,
        residentName: _residentName.text,
        data: data,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _message('Pengajuan gagal dikirim: ${friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(_isLetter ? 'Formulir Pengajuan Surat' : 'Lapor Tamu'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    if (_isLetter) ...[
                      _field('Nama', 'Nama lengkap', _residentName),
                      _field('Keperluan Surat', 'Jelaskan keperluan surat', _letterPurpose,
                          maxLines: 2),
                      _field('Nama Surat yang diminta', 'Contoh: Surat Domisili', _letterName),
                    ] else ...[
                      _field('Nama tamu', 'Nama lengkap', _guestName),
                      _field('Alamat asal', 'Alamat domisili tamu', _guestOrigin),
                      _field('Tujuan', 'Kunjungan keluarga', _guestPurpose, maxLines: 2),
                      Row(children: [
                        _dateField('Waktu mulai', _startsAt,
                            () => _chooseTime(start: true)),
                        const SizedBox(width: 10),
                        _dateField('Waktu selesai', _endsAt,
                            () => _chooseTime(start: false)),
                      ]),
                      const SizedBox(height: 5),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text('Durasi maksimal 24 jam.',
                            style: TextStyle(
                                color: appGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: _sending ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: appGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                          textStyle: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        child: Text(_sending ? 'Mengirim...' : 'Kirim pengajuan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _field(String label, String hint, TextEditingController controller,
      {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(label,
                style: const TextStyle(
                    color: appMuted, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: _required,
            decoration: _fieldDecoration(hint),
          ),
        ]),
      );

  Widget _dateField(String label, DateTime date, VoidCallback onTap) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(label,
                style: const TextStyle(
                    color: appMuted, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: appInk,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              side: const BorderSide(color: appBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
            ),
            child: Text(_formatDateTime(date),
                style: const TextStyle(fontSize: 10)),
          ),
        ]),
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: appMuted, fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: appBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: appGreen, width: 1.3)),
      );
}

class _RequestActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _RequestActionButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 15),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: appGreen,
            foregroundColor: Colors.white,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11)),
            textStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _CitizenRequestCard extends StatelessWidget {
  final CitizenRequest request;
  const _CitizenRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: appBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFE5F3EF),
          child: Icon(
            request.kind == 'letter' ? Icons.article_outlined : Icons.schedule_outlined,
            color: appGreen,
            size: 13,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request.title,
              style: const TextStyle(
                  color: appInk, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Diajukan ${_formatShortDate(request.createdAt)}',
              style: const TextStyle(color: appMuted, fontSize: 9)),
          if (request.kind == 'guest')
            Text('${request.data['guest_name'] ?? ''} · ${request.data['purpose'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: appMuted, fontSize: 9)),
          if (request.decisionDocumentPath != null)
            DecisionDocumentButton(path: request.decisionDocumentPath!),
        ])),
        const SizedBox(width: 8),
        _StatusBadge(status: request.status, color: statusColor),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(_statusLabel(status),
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.w700)),
      );
}

class _RequestNotice extends StatelessWidget {
  final String text;
  const _RequestNotice({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(text,
            style: const TextStyle(color: appMuted, fontSize: 10)),
      );
}

Color _statusColor(String status) => switch (status) {
      'approved' => appGreen,
      'rejected' => const Color(0xFFD95454),
      _ => const Color(0xFFCC8B19),
    };

String _statusLabel(String status) => switch (status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };

String _formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';

String _formatShortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${date.month.toString().padLeft(2, '0')} ${date.year}';
