import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentRecord {
  final String id;
  final String name;
  final String nik;
  final String address;
  final bool isAccount;

  const ResidentRecord({
    required this.id,
    required this.name,
    required this.nik,
    required this.address,
    required this.isAccount,
  });

  factory ResidentRecord.fromMap(Map<String, dynamic> row) => ResidentRecord(
        id: row['id'] as String,
        name: row['full_name'] as String,
        nik: row['nik'] as String,
        address: row['address'] as String,
        isAccount: false,
      );

  factory ResidentRecord.fromProfile(Map<String, dynamic> row) =>
      ResidentRecord(
        id: row['id'] as String,
        name: row['full_name'] as String? ?? '',
        nik: row['nik'] as String? ?? '',
        address: row['address'] as String? ?? '',
        isAccount: true,
      );
}

/// Realtime state and CRUD operations for the admin's resident directory.
class AdminResidentsController extends ChangeNotifier {
  final List<ResidentRecord> _residents = [];
  final List<ResidentRecord> _registeredResidents = [];
  late final StreamSubscription<List<Map<String, dynamic>>> _subscription;
  late final StreamSubscription<List<Map<String, dynamic>>> _profilesSubscription;
  bool _loading = true;
  bool _directoryLoaded = false;
  bool _profilesLoaded = false;
  bool _saving = false;
  String? _error;
  final Set<String> _deletingIds = {};
  bool _disposed = false;

  AdminResidentsController() {
    _profilesSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'warga')
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            if (_disposed) return;
            _registeredResidents
              ..clear()
              ..addAll(rows.map(ResidentRecord.fromProfile));
            _profilesLoaded = true;
            _loading = !(_profilesLoaded && _directoryLoaded);
            _error = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) return;
            _loading = false;
            _error = error.toString();
            notifyListeners();
          },
        );
    _subscription = Supabase.instance.client
        .from('resident_directory')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            if (_disposed) return;
            _residents
              ..clear()
              ..addAll(rows.map(ResidentRecord.fromMap));
            _directoryLoaded = true;
            _loading = !(_profilesLoaded && _directoryLoaded);
            _error = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) return;
            _loading = false;
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  List<ResidentRecord> get residents => List.unmodifiable(_residents);
  List<ResidentRecord> get registeredResidents =>
      List.unmodifiable(_registeredResidents);
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get error => _error;
  bool isDeleting(String id) => _deletingIds.contains(id);

  Future<void> addResident({
    required String name,
    required String nik,
    required String address,
  }) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      final matchingAccounts = await client
          .from('profiles')
          .select('id')
          .eq('role', 'warga')
          .eq('nik', nik.trim())
          .limit(1);
      if (matchingAccounts.isNotEmpty) {
        throw const FormatException('NIK ini sudah terdaftar sebagai akun warga.');
      }
      await client.from('resident_directory').insert({
        'full_name': name.trim(),
        'nik': nik.trim(),
        'address': address.trim(),
      });
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> deleteResident(String id) async {
    _deletingIds.add(id);
    _error = null;
    notifyListeners();
    try {
      await Supabase.instance.client
          .from('resident_directory')
          .delete()
          .eq('id', id);
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _deletingIds.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  /// Permanently deletes a registered warga from Supabase Auth and its profile.
  /// The Edge Function validates the current admin session before deletion.
  Future<void> deleteRegisteredResident(String id) async {
    _deletingIds.add(id);
    _error = null;
    notifyListeners();
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'admin-delete-resident',
        body: {'user_id': id},
      );
      if (result.status < 200 || result.status >= 300) {
        final body = result.data;
        throw Exception(body is Map ? body['error'] ?? body : body);
      }
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _deletingIds.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _profilesSubscription.cancel();
    super.dispose();
  }
}
