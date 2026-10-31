import 'package:flutter/material.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/duty_schedule_service.dart';

String _formatDutyDate(DateTime date) {
  const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

class AdminDutyScheduleScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const AdminDutyScheduleScreen({
    required this.onNavigateTab,
    super.key,
  });

  @override
  State<AdminDutyScheduleScreen> createState() =>
      _AdminDutyScheduleScreenState();
}

class _AdminDutyScheduleScreenState extends State<AdminDutyScheduleScreen> {
  int _selectedTab = 0;
  late final Stream<List<DutySchedule>> _scheduleStream;

  @override
  void initState() {
    super.initState();
    _scheduleStream = DutyScheduleService.watchAll();
  }

  Future<void> _addSchedule() async {
    final result = await Navigator.of(context).push<DutyScheduleDraft>(
      MaterialPageRoute(
        builder: (_) => _AddDutySchedulePage(
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await DutyScheduleService.create(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal jaga berhasil dikirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jadwal gagal disimpan: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeSchedule(DutySchedule shift) async {
    try {
      await DutyScheduleService.delete(shift.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jadwal gagal dihapus: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Widget> _buildScheduleList(AsyncSnapshot<List<DutySchedule>> snapshot) {
    if (snapshot.hasError) {
      return [
        _EmptySchedule(
            text: 'Jadwal belum dapat dimuat. Pastikan tabel duty_schedules sudah tersedia.'),
      ];
    }
    if (!snapshot.hasData) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: appGreen)),
        ),
      ];
    }
    final schedules = snapshot.data!;
    if (schedules.isEmpty) {
      return const [
        _EmptySchedule(text: 'Belum ada jadwal jaga. Tambahkan jadwal baru.'),
      ];
    }

    final grouped = <DateTime, List<DutySchedule>>{};
    for (final shift in schedules) {
      final date = DateTime(
          shift.startsAt.year, shift.startsAt.month, shift.startsAt.day);
      grouped.putIfAbsent(date, () => []).add(shift);
    }
    return [
      for (final entry in grouped.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            _formatDutyDate(entry.key),
            style: const TextStyle(
                color: appInk, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        for (final shift in entry.value) ...[
          _ShiftCard(
            shift: shift,
            onDelete: () => _removeSchedule(shift),
          ),
          const SizedBox(height: 7),
        ],
      ],
    ];
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
                child: Text('RT',
                    style: TextStyle(
                        color: appGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                children: [
                  const Text(
                    'Jadwal Jaga',
                    style: TextStyle(
                        color: appInk,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w800),
                  ),
                  const Text('Mode administrasi.',
                      style: TextStyle(color: appMuted, fontSize: 10)),
                  const SizedBox(height: 11),
                  const _ScheduleNotice(),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 37,
                    child: FilledButton.icon(
                      onPressed: _addSchedule,
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Tambah Jadwal Jaga'),
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const SizedBox(height: 7),
                  StreamBuilder<List<DutySchedule>>(
                    stream: _scheduleStream,
                    builder: (context, snapshot) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildScheduleList(snapshot),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE5F3EF),
          selectedIndex: _selectedTab,
          onDestinationSelected: (index) {
            setState(() => _selectedTab = index);
            Navigator.of(context).pop();
            widget.onNavigateTab(index);
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.check_circle_outline), label: 'Setujui'),
            NavigationDestination(
                icon: Icon(Icons.groups_2_outlined), label: 'Warga'),
            NavigationDestination(
                icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
          ],
        ),
      );
}

class _ScheduleNotice extends StatelessWidget {
  const _ScheduleNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5F3EF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Tambah dan atur petugas tiap shift.',
          style: TextStyle(
              color: appGreen, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
}

class _ShiftCard extends StatelessWidget {
  final DutySchedule shift;
  final VoidCallback onDelete;

  const _ShiftCard({required this.shift, required this.onDelete});

  @override
  Widget build(BuildContext context) => _ScheduleCardShell(
        child: Row(
          children: [
            const _ClockBadge(),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shift.residentName,
                      style: const TextStyle(
                          color: appInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      'Shift ${shift.shiftName} · ${_formatClock(shift.startsAt)}–${_formatClock(shift.endsAt)}',
                      style: const TextStyle(color: appMuted, fontSize: 9)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opsi jadwal',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              icon: const Icon(Icons.more_vert, color: appMuted, size: 15),
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Hapus jadwal')),
              ],
            ),
          ],
        ),
      );
}

String _formatClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';

class _ScheduleCardShell extends StatelessWidget {
  final Widget child;

  const _ScheduleCardShell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 43),
        padding: const EdgeInsets.fromLTRB(9, 6, 7, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

class _ClockBadge extends StatelessWidget {
  const _ClockBadge();

  @override
  Widget build(BuildContext context) => const CircleAvatar(
        radius: 10,
        backgroundColor: Color(0xFFE5F3EF),
        child: Icon(Icons.access_time, color: Color(0xFF7DBDAD), size: 11),
      );
}

class _EmptySchedule extends StatelessWidget {
  final String text;

  const _EmptySchedule({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: const TextStyle(color: appMuted, fontSize: 10)),
      );
}

class _AddDutySchedulePage extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const _AddDutySchedulePage({required this.onNavigateTab});

  @override
  State<_AddDutySchedulePage> createState() => _AddDutySchedulePageState();
}

class _AddDutySchedulePageState extends State<_AddDutySchedulePage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedShift;
  DateTime? _startAt;
  DateTime? _endAt;
  int _selectedTab = 0;

  static const _shifts = [
    'Pagi',
    'Sore',
    'Malam',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.fromDateTime(now)
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Pilih tanggal dan waktu';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hour:$minute';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startAt == null || _endAt == null) {
      _showError('Pilih waktu mulai dan waktu selesai.');
      return;
    }
    final duration = _endAt!.difference(_startAt!);
    if (duration <= Duration.zero) {
      _showError('Waktu selesai harus setelah waktu mulai.');
      return;
    }
    if (duration > const Duration(hours: 24)) {
      _showError('Durasi jadwal maksimal 24 jam.');
      return;
    }
    final start = _startAt!;
    final end = _endAt!;
    Navigator.pop(
      context,
      DutyScheduleDraft(
        residentName: _nameController.text.trim(),
        shiftName: _selectedShift!,
        startsAt: start,
        endsAt: end,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _dateTimeField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: appMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: appBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 16, color: appGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_formatDateTime(value),
                          style: TextStyle(
                              color: value == null ? appMuted : appInk,
                              fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  void _navigateTab(int index) {
    setState(() => _selectedTab = index);
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onNavigateTab(index);
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
                child: Text('YA',
                    style: TextStyle(
                        color: appGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: appBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nama security',
                              style: TextStyle(
                                  color: appMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                                hintText: 'Nama lengkap'),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Nama security wajib diisi.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          const Text('Shift',
                              style: TextStyle(
                                  color: appMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedShift,
                            decoration: const InputDecoration(
                                hintText: 'Isi shift, pagi/malam'),
                            items: [
                              for (final shift in _shifts)
                                DropdownMenuItem(value: shift, child: Text(shift)),
                            ],
                            validator: (value) =>
                                value == null ? 'Pilih shift.' : null,
                            onChanged: (value) =>
                                setState(() => _selectedShift = value),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _dateTimeField(
                                label: 'Waktu mulai',
                                value: _startAt,
                                onTap: () async {
                                  final value = await _pickDateTime(_startAt);
                                  if (value != null) setState(() => _startAt = value);
                                },
                              ),
                              const SizedBox(width: 10),
                              _dateTimeField(
                                label: 'Waktu selesai',
                                value: _endAt,
                                onTap: () async {
                                  final value = await _pickDateTime(_endAt);
                                  if (value != null) setState(() => _endAt = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          const Text('Durasi maksimal 24 jam.',
                              style: TextStyle(
                                  color: appGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: appGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              child: const Text('Kirim'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE5F3EF),
          selectedIndex: _selectedTab,
          onDestinationSelected: _navigateTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Setujui'),
            NavigationDestination(icon: Icon(Icons.groups_2_outlined), label: 'Warga'),
            NavigationDestination(icon: Icon(Icons.account_circle_outlined), label: 'Profil'),
          ],
        ),
      );
}
