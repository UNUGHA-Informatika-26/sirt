import 'package:supabase_flutter/supabase_flutter.dart';

import 'decision_document_service.dart';

class InventoryItem {
  final String id;
  final String name;
  final int stock;

  const InventoryItem({required this.id, required this.name, required this.stock});

  factory InventoryItem.fromMap(Map<String, dynamic> row) => InventoryItem(
        id: row['id'] as String,
        name: row['name'] as String,
        stock: (row['stock'] as num).toInt(),
      );
}

class EquipmentLoanRequest {
  final String id;
  final String userId;
  final String itemId;
  final String itemName;
  final String residentName;
  final String purpose;
  final DateTime loanDate;
  final DateTime returnDate;
  final String status;
  final String? decisionDocumentPath;

  const EquipmentLoanRequest({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.residentName,
    required this.purpose,
    required this.loanDate,
    required this.returnDate,
    required this.status,
    required this.decisionDocumentPath,
  });

  factory EquipmentLoanRequest.fromMap(Map<String, dynamic> row) =>
      EquipmentLoanRequest(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        itemId: row['item_id'] as String,
        itemName: row['item_name'] as String,
        residentName: row['resident_name'] as String,
        purpose: row['purpose'] as String,
        loanDate: DateTime.parse(row['loan_date'] as String),
        returnDate: DateTime.parse(row['return_date'] as String),
        status: row['status'] as String,
        decisionDocumentPath: row['decision_document_path'] as String?,
      );
}

class EquipmentLoanService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<List<InventoryItem>> watchInventory() => _client
      .from('inventory_items')
      .stream(primaryKey: ['id'])
      .order('name')
      .map((rows) => rows.map(InventoryItem.fromMap).toList());

  static Stream<List<EquipmentLoanRequest>> watchMyRequests(String userId) =>
      _client
          .from('equipment_loan_requests')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map(EquipmentLoanRequest.fromMap).toList());

  static Stream<List<EquipmentLoanRequest>> watchAllRequests() => _client
      .from('equipment_loan_requests')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(EquipmentLoanRequest.fromMap).toList());

  static Future<void> submit({
    required InventoryItem item,
    required String purpose,
    required DateTime loanDate,
    required DateTime returnDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');
    final profile = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single();
    final profileName = (profile['full_name'] as String? ?? '').trim();
    await _client.from('equipment_loan_requests').insert({
      'user_id': user.id,
      'resident_name': profileName.isNotEmpty ? profileName : user.email ?? 'Warga',
      'item_id': item.id,
      'item_name': item.name,
      'purpose': purpose.trim(),
      'loan_date': _dateOnly(loanDate),
      'return_date': _dateOnly(returnDate),
    });
  }

  static Future<void> review({
    required EquipmentLoanRequest request,
    required bool approve,
    DecisionDocumentFile? document,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');
    String? documentPath;
    try {
      if (approve) {
        if (document == null) {
          throw ArgumentError('Dokumen persetujuan peminjaman wajib dipilih.');
        }
        documentPath = await DecisionDocumentService.upload(
          document,
          userId: request.userId,
          requestId: request.id,
        );
      }
      final updated = await _client
          .from('equipment_loan_requests')
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

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
