import 'package:supabase_flutter/supabase_flutter.dart';

import 'decision_document_service.dart';

class CitizenRequest {
  final String id;
  final String userId;
  final String kind;
  final String residentName;
  final Map<String, dynamic> data;
  final String status;
  final DateTime createdAt;
  final String? decisionDocumentPath;

  const CitizenRequest({
    required this.id,
    required this.userId,
    required this.kind,
    required this.residentName,
    required this.data,
    required this.status,
    required this.createdAt,
    required this.decisionDocumentPath,
  });

  factory CitizenRequest.fromMap(Map<String, dynamic> row) => CitizenRequest(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        kind: row['request_type'] as String,
        residentName: row['resident_name'] as String,
        data: Map<String, dynamic>.from(row['request_data'] as Map),
        status: row['status'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        decisionDocumentPath: row['decision_document_path'] as String?,
      );

  String get title => kind == 'letter' ? 'Surat ${data['letter_name'] ?? ''}' : 'Lapor tamu';
}

class CitizenRequestService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<List<CitizenRequest>> watchMine(String userId) => _client
      .from('citizen_service_requests')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(CitizenRequest.fromMap).toList());

  static Stream<List<CitizenRequest>> watchAll() => _client
      .from('citizen_service_requests')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(CitizenRequest.fromMap).toList());

  static Future<void> submit({
    required String type,
    required String residentName,
    required Map<String, dynamic> data,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');
    await _client.from('citizen_service_requests').insert({
      'user_id': user.id,
      'resident_name': residentName.trim(),
      'request_type': type,
      'request_data': data,
    });
  }

  static Future<void> review({
    required CitizenRequest request,
    required bool approve,
    DecisionDocumentFile? document,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');
    String? documentPath;
    try {
      if (approve) {
        if (document == null) {
          throw ArgumentError('Dokumen persetujuan wajib dipilih.');
        }
        documentPath = await DecisionDocumentService.upload(
          document,
          userId: request.userId,
          requestId: request.id,
        );
      }
      final updated = await _client
          .from('citizen_service_requests')
          .update({
            'status': approve ? 'approved' : 'rejected',
            'reviewed_by': user.id,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'decision_document_path': documentPath,
          })
          .eq('id', request.id)
          .eq('status', 'pending')
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw StateError('Pengajuan sudah diproses sebelumnya.');
      }
    } catch (_) {
      if (documentPath != null) {
        await DecisionDocumentService.remove(documentPath);
      }
      rethrow;
    }
  }
}
