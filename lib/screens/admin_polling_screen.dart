import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/poll_service.dart';

class AdminPollingScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const AdminPollingScreen({required this.onNavigateTab, super.key});

  @override
  State<AdminPollingScreen> createState() => _AdminPollingScreenState();
}

class _AdminPollingScreenState extends State<AdminPollingScreen> {
  int _selectedTab = 0;
  late final Stream<List<CommunityPoll>> _pollStream;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _pollStream = PollService.watchPolls();
  }

  Future<void> _openCreatePoll() async {
    final draft = await Navigator.of(context).push<CommunityPollDraft>(
      MaterialPageRoute(builder: (_) => const _CreatePollPage()),
    );
    if (draft == null || !mounted) return;
    try {
      await PollService.create(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Polling berhasil ditambahkan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Polling gagal disimpan: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deletePoll(CommunityPoll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus polling permanen?'),
        content: Text('"${poll.title}" dan semua suara terkait akan dihapus. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus permanen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await PollService.delete(poll.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Polling dan suaranya telah dihapus permanen.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Polling gagal dihapus: $error')),
      );
    }
  }

  void _scheduleExpiryRefresh(List<CommunityPoll> polls) {
    _expiryTimer?.cancel();
    final now = DateTime.now();
    DateTime? nextExpiry;
    for (final poll in polls) {
      if (!poll.isExpired && (nextExpiry == null || poll.expiresAt.isBefore(nextExpiry))) {
        nextExpiry = poll.expiresAt;
      }
    }
    if (nextExpiry == null) return;
    _expiryTimer = Timer(nextExpiry.difference(now), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

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
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
                children: [
                  const Text('Musyawarah',
                      style: TextStyle(
                          color: appInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Pendapat warga untuk keputusan bersama.',
                      style: TextStyle(color: appMuted, fontSize: 10)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F3EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Musyawarah',
                            style: TextStyle(
                                color: appGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: FilledButton.icon(
                            onPressed: _openCreatePoll,
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text('Tambah Poling'),
                            style: FilledButton.styleFrom(
                              backgroundColor: appGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<CommunityPoll>>(
                    stream: _pollStream,
                    builder: (context, snapshot) =>
                        _buildPollSections(snapshot),
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

  Widget _buildPollSections(AsyncSnapshot<List<CommunityPoll>> snapshot) {
    const titleStyle = TextStyle(
        color: appInk, fontSize: 13, fontWeight: FontWeight.w700);
    if (snapshot.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Polling aktif', style: titleStyle),
          const SizedBox(height: 6),
          const _PollEmptyCard(text: 'Polling gagal dimuat. Periksa koneksi.'),
        ],
      );
    }
    if (!snapshot.hasData) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Polling aktif', style: titleStyle),
          SizedBox(height: 6),
          _PollLoadingCard(),
          SizedBox(height: 8),
          Text('Hasil polling', style: titleStyle),
          SizedBox(height: 6),
          _PollEmptyCard(text: 'Hasil polling akan tampil di sini.'),
        ],
      );
    }
    final allPolls = snapshot.data!;
    _scheduleExpiryRefresh(allPolls);
    final polls = allPolls.where((poll) => !poll.isExpired).toList();
    final results = polls.where((poll) => poll.totalVotes > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Polling aktif', style: titleStyle),
        const SizedBox(height: 6),
        if (polls.isEmpty)
          const _PollEmptyCard(text: 'Belum Ada Polling')
        else
          for (final poll in polls) ...[
            _AdminPollCard(poll: poll, onDelete: () => _deletePoll(poll)),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 4),
        const Text('Hasil polling', style: titleStyle),
        const SizedBox(height: 6),
        if (results.isEmpty)
          const _PollEmptyCard(text: 'Belum ada suara dari warga.')
        else
          for (final poll in results) ...[
            _PollResultCard(poll: poll),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CreatePollPage extends StatefulWidget {
  const _CreatePollPage();

  @override
  State<_CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<_CreatePollPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _firstController = TextEditingController();
  final _secondController = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _titleController.dispose();
    _firstController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (selected != null) setState(() => _date = selected);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih waktu polling terlebih dahulu.')),
      );
      return;
    }
    Navigator.pop(
      context,
      CommunityPollDraft(
        title: _titleController.text.trim(),
        optionOne: _firstController.text.trim(),
        optionTwo: _secondController.text.trim(),
        pollDate: _date!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          titleSpacing: 20,
          title: const SirtLogo(),
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
                    padding: const EdgeInsets.all(14),
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
                          _PollTextField(
                            label: 'Judul polling',
                            hint: 'Contoh: Pemilihan waktu kerja bakti',
                            controller: _titleController,
                          ),
                          const SizedBox(height: 10),
                          _PollTextField(
                              label: 'Nama pilihan 1',
                              hint: 'Pilihan pertama',
                              controller: _firstController),
                          const SizedBox(height: 10),
                          _PollTextField(
                              label: 'Nama pilihan 2',
                              hint: 'Pilihan kedua',
                              controller: _secondController),
                          const SizedBox(height: 10),
                          const Text('Waktu',
                              style: TextStyle(
                                  color: appMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: _chooseDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 46,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 11),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: appBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _date == null
                                          ? 'Pilih tanggal'
                                          : _formatDate(_date!),
                                      style: TextStyle(
                                          color: _date == null
                                              ? appMuted
                                              : appInk,
                                          fontSize: 11),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_month_outlined,
                                      color: appGreen, size: 17),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 42,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: appGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11)),
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
      );
}

class _PollTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _PollTextField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: appMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Bagian ini wajib diisi.'
                : null,
          ),
        ],
      );
}

class _AdminPollCard extends StatelessWidget {
  final CommunityPoll poll;
  final VoidCallback onDelete;

  const _AdminPollCard({required this.poll, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Musyawarah', style: TextStyle(color: appGreen, fontSize: 9, fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Hapus polling permanen',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC84C4C), size: 18),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(poll.title,
                style: const TextStyle(
                    color: appInk, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            _AdminPollOption(option: poll.optionOne),
            _AdminPollOption(option: poll.optionTwo),
            const SizedBox(height: 5),
            Text('${_formatPollDate(poll.pollDate)} · ${poll.totalVotes} suara',
                style: const TextStyle(color: appMuted, fontSize: 9)),
          ],
        ),
      );
}

class _AdminPollOption extends StatelessWidget {
  final String option;

  const _AdminPollOption({required this.option});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            const Icon(Icons.circle_outlined, color: appGreen, size: 12),
            const SizedBox(width: 7),
            Expanded(
              child: Text(option,
                  style: const TextStyle(color: appInk, fontSize: 10)),
            ),
          ],
        ),
      );
}

class _PollResultCard extends StatelessWidget {
  final CommunityPoll poll;

  const _PollResultCard({required this.poll});

  Widget _resultLine(String option, int votes, int total) {
    final fraction = total == 0 ? 0.0 : votes / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$option · ${(fraction * 100).round()}%',
            style: const TextStyle(color: appMuted, fontSize: 9)),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: const Color(0xFFE5F3EF),
            color: appGreen,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.title,
                style: const TextStyle(
                    color: appInk, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _resultLine(poll.optionOne, poll.optionOneVotes, poll.totalVotes),
            const SizedBox(height: 6),
            _resultLine(poll.optionTwo, poll.optionTwoVotes, poll.totalVotes),
            const SizedBox(height: 6),
            Text('Total ${poll.totalVotes} suara',
                style: const TextStyle(color: appMuted, fontSize: 9)),
          ],
        ),
      );
}

class _PollEmptyCard extends StatelessWidget {
  final String text;

  const _PollEmptyCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 68),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: appBorder),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(text,
            style: const TextStyle(
                color: appInk, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

class _PollLoadingCard extends StatelessWidget {
  const _PollLoadingCard();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: appGreen)),
      );
}

String _formatPollDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
