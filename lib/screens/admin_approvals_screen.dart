import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/decision_document_service.dart';
import '../services/citizen_request_service.dart';
import '../services/equipment_loan_service.dart';
import '../utils/app_error.dart';
import 'admin_document_upload_screen.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  late final Stream<List<CitizenRequest>> _citizenRequests;
  late final Stream<List<EquipmentLoanRequest>> _loans;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _citizenRequests = CitizenRequestService.watchAll();
    _loans = EquipmentLoanService.watchAllRequests();
  }

  Future<void> _reviewCitizenRequest(
    CitizenRequest request, {
    required bool approve,
  }) async {
    DecisionDocumentFile? document;
    if (approve) {
      final subject = request.kind == 'letter'
          ? request.title
          : 'Surat persetujuan tamu · ${request.data['guest_name'] ?? request.residentName}';
      document = await _pickDecisionDocument(subject);
      if (document == null) return;
    }
    await _performReview(
      id: request.id,
      action: () => CitizenRequestService.review(
          request: request, approve: approve, document: document),
      success: approve
          ? 'Dokumen persetujuan diunggah dan dikirim ke akun warga.'
          : 'Pengajuan ditolak.',
    );
  }

  Future<void> _reviewLoan(
    EquipmentLoanRequest request, {
    required bool approve,
  }) async {
    DecisionDocumentFile? document;
    if (approve) {
      document = await _pickDecisionDocument('Peminjaman ${request.itemName}');
      if (document == null) return;
    }
    await _performReview(
      id: request.id,
      action: () => EquipmentLoanService.review(
          request: request, approve: approve, document: document),
      success: approve
          ? 'Surat peminjaman diunggah dan dikirim ke akun warga.'
          : 'Peminjaman ditolak.',
    );
  }

  Future<DecisionDocumentFile?> _pickDecisionDocument(String subject) async =>
      Navigator.of(context).push<DecisionDocumentFile>(
        MaterialPageRoute(
          builder: (_) => AdminDocumentUploadScreen(subject: subject),
        ),
      );

  Future<void> _performReview({
    required String id,
    required Future<void> Function() action,
    required String success,
  }) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (!mounted) return;
      _message(success);
    } catch (error) {
      if (!mounted) return;
      _message('Status gagal diperbarui: ${friendlyError(error)}');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
            children: [
              const Text('Persetujuan',
                  style: TextStyle(
                      color: appInk,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text('Tinjau permohonan surat, laporan tamu, dan inventaris.',
                  style: TextStyle(color: appMuted, fontSize: 10)),
              const SizedBox(height: 11),
              const _NoticeBanner(),
              const SizedBox(height: 14),
              _CitizenRequestApprovalSection(
                requests: _citizenRequests,
                busyId: _busyId,
                onReview: _reviewCitizenRequest,
              ),
              const SizedBox(height: 18),
              _EquipmentLoanApprovalSection(
                requests: _loans,
                busyId: _busyId,
                onReview: _reviewLoan,
              ),
            ],
          ),
        ),
      );
}

class _CitizenRequestApprovalSection extends StatelessWidget {
  final Stream<List<CitizenRequest>> requests;
  final String? busyId;
  final Future<void> Function(CitizenRequest request, {required bool approve})
      onReview;

  const _CitizenRequestApprovalSection({
    required this.requests,
    required this.busyId,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Surat dan laporan tamu',
              style: TextStyle(
                  color: appInk, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<List<CitizenRequest>>(
            stream: requests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ApprovalEmpty(
                    text: 'Pengajuan tidak dapat dimuat: ${friendlyError(snapshot.error!)}');
              }
              if (!snapshot.hasData) return const _ApprovalLoading();
              final all = snapshot.data!;
              final pending = all.where((request) => request.status == 'pending');
              final history = all.where((request) => request.status != 'pending');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pending.isEmpty)
                    const _ApprovalEmpty(
                        text: 'Tidak ada pengajuan surat atau tamu yang menunggu.'),
                  for (final request in pending) ...[
                    _ServiceRequestApprovalCard(
                      request: request,
                      busy: busyId == request.id,
                      onReject: () => onReview(request, approve: false),
                      onApprove: () => onReview(request, approve: true),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 5),
                  const Text('Riwayat disetujui atau ditolak',
                      style: TextStyle(
                          color: appInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  if (history.isEmpty)
                    const _ApprovalEmpty(text: 'Belum ada keputusan.'),
                  for (final request in history) ...[
                    _ServiceRequestHistoryCard(request: request),
                    const SizedBox(height: 7),
                  ],
                ],
              );
            },
          ),
        ],
      );
}

class _EquipmentLoanApprovalSection extends StatelessWidget {
  final Stream<List<EquipmentLoanRequest>> requests;
  final String? busyId;
  final Future<void> Function(EquipmentLoanRequest request,
      {required bool approve}) onReview;

  const _EquipmentLoanApprovalSection({
    required this.requests,
    required this.busyId,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Peminjaman inventaris',
              style: TextStyle(
                  color: appInk, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<List<EquipmentLoanRequest>>(
            stream: requests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ApprovalEmpty(
                    text: 'Peminjaman tidak dapat dimuat: ${friendlyError(snapshot.error!)}');
              }
              if (!snapshot.hasData) return const _ApprovalLoading();
              final all = snapshot.data!;
              final pending = all.where((request) => request.status == 'pending');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pending.isEmpty)
                    const _ApprovalEmpty(
                        text: 'Belum ada peminjaman yang menunggu.'),
                  for (final request in pending) ...[
                    _EquipmentLoanApprovalCard(
                      request: request,
                      busy: busyId == request.id,
                      onReject: () => onReview(request, approve: false),
                      onApprove: () => onReview(request, approve: true),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      );
}

class _ServiceRequestApprovalCard extends StatelessWidget {
  final CitizenRequest request;
  final bool busy;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const _ServiceRequestApprovalCard({
    required this.request,
    required this.busy,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) => _ApprovalCardFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _RequestIcon(
                icon: request.kind == 'letter'
                    ? Icons.article_outlined
                    : Icons.schedule_outlined),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.kind == 'letter' ? 'Surat ${request.data['letter_name'] ?? ''}' : 'Lapor tamu',
                  style: const TextStyle(
                      color: appInk, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${request.residentName} · Warga',
                  style: const TextStyle(color: appMuted, fontSize: 9)),
            ])),
          ]),
          const SizedBox(height: 8),
          if (request.kind == 'letter') ...[
            _DetailLine('Keperluan', '${request.data['purpose'] ?? '-'}'),
            _DetailLine('Nama pemohon', '${request.data['applicant_name'] ?? request.residentName}'),
          ] else ...[
            _DetailLine('Nama tamu', '${request.data['guest_name'] ?? '-'}'),
            _DetailLine('Alamat asal', '${request.data['guest_origin'] ?? '-'}'),
            _DetailLine('Tujuan', '${request.data['purpose'] ?? '-'}'),
            _DetailLine('Waktu', _guestTime(request.data)),
          ],
          const SizedBox(height: 9),
          _DecisionRow(busy: busy, onReject: onReject, onApprove: onApprove),
        ]),
      );
}

class _EquipmentLoanApprovalCard extends StatelessWidget {
  final EquipmentLoanRequest request;
  final bool busy;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const _EquipmentLoanApprovalCard({
    required this.request,
    required this.busy,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) => _ApprovalCardFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const _RequestIcon(icon: Icons.inventory_2_outlined),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.itemName,
                  style: const TextStyle(
                      color: appInk, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${request.residentName} · Warga',
                  style: const TextStyle(color: appMuted, fontSize: 9)),
            ])),
          ]),
          const SizedBox(height: 8),
          _DetailLine('Tujuan', request.purpose),
          _DetailLine('Tanggal', '${_formatDate(request.loanDate)} – ${_formatDate(request.returnDate)}'),
          const SizedBox(height: 9),
          _DecisionRow(busy: busy, onReject: onReject, onApprove: onApprove),
        ]),
      );
}

class _DecisionRow extends StatelessWidget {
  final bool busy;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  const _DecisionRow({required this.busy, required this.onReject, required this.onApprove});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _DecisionButton(label: 'Tolak', approved: false, onPressed: busy ? null : onReject)),
        const SizedBox(width: 8),
        Expanded(child: _DecisionButton(label: busy ? '...' : 'Setujui', approved: true, onPressed: busy ? null : onApprove)),
      ]);
}

class _ServiceRequestHistoryCard extends StatelessWidget {
  final CitizenRequest request;
  const _ServiceRequestHistoryCard({required this.request});

  @override
  Widget build(BuildContext context) => _HistoryCard(
        icon: request.kind == 'letter' ? Icons.article_outlined : Icons.schedule_outlined,
        title: request.kind == 'letter' ? 'Surat ${request.data['letter_name'] ?? ''}' : 'Lapor tamu · ${request.data['guest_name'] ?? ''}',
        subtitle: '${request.residentName} · ${_formatDate(request.createdAt)}',
        status: request.status,
      );
}

class _HistoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  const _HistoryCard({required this.icon, required this.title, required this.subtitle, required this.status});

  @override
  Widget build(BuildContext context) => _ApprovalCardFrame(
        child: Row(children: [
          _RequestIcon(icon: icon),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: appInk, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: appMuted, fontSize: 9)),
          ])),
          _StatusPill(status: status),
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = switch (status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  const _DetailLine(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text('$label: $value', style: const TextStyle(color: appMuted, fontSize: 9)),
      );
}

class _ApprovalCardFrame extends StatelessWidget {
  final Widget child;
  const _ApprovalCardFrame({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: appBorder), borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class _ApprovalEmpty extends StatelessWidget {
  final String text;
  const _ApprovalEmpty({required this.text});
  @override
  Widget build(BuildContext context) => _ApprovalCardFrame(
        child: Row(children: [
          const Icon(Icons.info_outline, color: appGreen, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: appMuted, fontSize: 10))),
        ]),
      );
}

class _ApprovalLoading extends StatelessWidget {
  const _ApprovalLoading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: appGreen)),
      );
}

class _RequestIcon extends StatelessWidget {
  final IconData icon;
  const _RequestIcon({required this.icon});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 13,
        backgroundColor: const Color(0xFFE5F3EF),
        child: Icon(icon, color: appGreen, size: 13),
      );
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final bool approved;
  final VoidCallback? onPressed;
  const _DecisionButton({required this.label, required this.approved, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 28,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            elevation: 0,
            backgroundColor: approved ? appGreen : const Color(0xFFFCE9E8),
            foregroundColor: approved ? Colors.white : const Color(0xFFD95454),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      );
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFFE5F3EF), borderRadius: BorderRadius.circular(13)),
        child: const Text('Semua pengajuan perlu ditinjau.', style: TextStyle(color: appGreen, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

String _guestTime(Map<String, dynamic> data) {
  final start = DateTime.parse(data['starts_at'] as String).toLocal();
  final end = DateTime.parse(data['ends_at'] as String).toLocal();
  return '${_formatDateTime(start)} – ${_formatDateTime(end)}';
}

Color _statusColor(String status) => switch (status) {
      'approved' => appGreen,
      'rejected' => const Color(0xFFD95454),
      _ => const Color(0xFFCC8B19),
    };

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

String _formatDateTime(DateTime date) =>
    '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
