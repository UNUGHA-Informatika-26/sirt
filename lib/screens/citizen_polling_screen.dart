import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/poll_service.dart';

class CitizenPollingScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const CitizenPollingScreen({required this.onNavigateTab, super.key});

  @override
  State<CitizenPollingScreen> createState() => _CitizenPollingScreenState();
}

class _CitizenPollingScreenState extends State<CitizenPollingScreen> {
  late final Stream<List<CommunityPoll>> _pollStream;
  late final Stream<List<PollVote>> _voteStream;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _pollStream = PollService.watchPolls();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    _voteStream = userId == null
        ? Stream<List<PollVote>>.value(const [])
        : PollService.watchMyVotes(userId);
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
                children: [
                  const Text('Musyawarah',
                      style: TextStyle(
                          color: appInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Ikut menentukan keputusan bersama.',
                      style: TextStyle(color: appMuted, fontSize: 10)),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F3EF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Text(
                      'Suara warga berhasil tercatat.',
                      style: TextStyle(
                          color: appGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Polling aktif',
                      style: TextStyle(
                          color: appInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  StreamBuilder<List<CommunityPoll>>(
                    stream: _pollStream,
                    builder: (context, pollsSnapshot) {
                      if (pollsSnapshot.hasError) {
                        return const _PollStateCard(
                            text: 'Polling tidak dapat dimuat. Periksa koneksi.');
                      }
                      if (!pollsSnapshot.hasData) {
                        return const _PollLoading();
                      }
                      final allPolls = pollsSnapshot.data!;
                      _scheduleExpiryRefresh(allPolls);
                      return StreamBuilder<List<PollVote>>(
                        stream: _voteStream,
                        builder: (context, votesSnapshot) {
                          if (votesSnapshot.hasError) {
                            return const _PollStateCard(
                                text: 'Status suara belum dapat dimuat.');
                          }
                          if (!votesSnapshot.hasData) {
                            return const _PollLoading();
                          }
                          final myVotes = {
                            for (final vote in votesSnapshot.data!)
                              vote.pollId: vote.optionIndex,
                          };
                          final polls = allPolls.where((poll) => !poll.isExpired).toList();
                          if (polls.isEmpty) {
                            return const _PollStateCard(
                                text: 'Belum ada polling dari admin.');
                          }
                          return _PollsContent(polls: polls, myVotes: myVotes);
                        },
                      );
                    },
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

class _PollsContent extends StatelessWidget {
  final List<CommunityPoll> polls;
  final Map<String, int> myVotes;

  const _PollsContent({required this.polls, required this.myVotes});

  @override
  Widget build(BuildContext context) {
    final completedPolls = polls.where((poll) => poll.totalVotes > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final poll in polls) ...[
          _CitizenPollCard(
            key: ValueKey(poll.id),
            poll: poll,
            myVote: myVotes[poll.id],
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        const Text('Hasil polling',
            style: TextStyle(
                color: appInk, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (completedPolls.isEmpty)
          const _PollStateCard(text: 'Belum ada suara dari warga.')
        else
          for (final poll in completedPolls) ...[
            _CitizenPollResultCard(poll: poll),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CitizenPollCard extends StatefulWidget {
  final CommunityPoll poll;
  final int? myVote;

  const _CitizenPollCard({required this.poll, required this.myVote, super.key});

  @override
  State<_CitizenPollCard> createState() => _CitizenPollCardState();
}

class _CitizenPollCardState extends State<_CitizenPollCard> {
  int? _selectedOption;
  bool _sending = false;
  bool _sentThisSession = false;

  Future<void> _sendVote() async {
    final choice = _selectedOption;
    if (choice == null || _sending || widget.myVote != null || _sentThisSession) {
      return;
    }
    setState(() => _sending = true);
    try {
      await PollService.castVote(pollId: widget.poll.id, optionIndex: choice);
      if (!mounted) return;
      setState(() => _sentThisSession = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suara berhasil dikirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suara gagal dikirim: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _choice(int index, String label) {
    final voted = widget.myVote ?? (_sentThisSession ? _selectedOption : null);
    final checked = _selectedOption == index || voted == index;
    final locked = widget.myVote != null || _sentThisSession || _sending;
    return InkWell(
      onTap: locked ? null : () => setState(() => _selectedOption = index),
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              color: checked ? appGreen : appMuted,
              size: 15,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: appInk, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVoted = widget.myVote != null || _sentThisSession;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: appBorder),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Musyawarah',
              style: TextStyle(
                  color: appGreen, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(widget.poll.title,
              style: const TextStyle(
                  color: appInk, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Pilih waktu yang paling sesuai untuk warga.',
              style: TextStyle(color: appMuted, fontSize: 9)),
          const SizedBox(height: 4),
          _choice(1, widget.poll.optionOne),
          _choice(2, widget.poll.optionTwo),
          if (hasVoted)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text('Suara kamu sudah tercatat.',
                  style: TextStyle(
                      color: appGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            )
          else ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 34,
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedOption == null || _sending ? null : _sendVote,
                style: FilledButton.styleFrom(
                  backgroundColor: appGreen,
                  disabledBackgroundColor: const Color(0xFF9FCFC3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  textStyle: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700),
                ),
                child: _sending
                    ? const SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kirim suara'),
              ),
            ),
          ],
          const SizedBox(height: 5),
          Text('${_formatPollDate(widget.poll.pollDate)} · ${widget.poll.totalVotes} suara',
              style: const TextStyle(color: appMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

class _CitizenPollResultCard extends StatelessWidget {
  final CommunityPoll poll;

  const _CitizenPollResultCard({required this.poll});

  Widget _line(String label, int count, int total) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · ${(fraction * 100).round()}%',
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
            _line(poll.optionOne, poll.optionOneVotes, poll.totalVotes),
            const SizedBox(height: 6),
            _line(poll.optionTwo, poll.optionTwoVotes, poll.totalVotes),
            const SizedBox(height: 6),
            Text('Total ${poll.totalVotes} suara',
                style: const TextStyle(color: appMuted, fontSize: 9)),
          ],
        ),
      );
}

class _PollStateCard extends StatelessWidget {
  final String text;

  const _PollStateCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
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

class _PollLoading extends StatelessWidget {
  const _PollLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: appGreen)),
      );
}

String _formatPollDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
