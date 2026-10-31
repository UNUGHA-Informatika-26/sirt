import 'package:supabase_flutter/supabase_flutter.dart';

class DutySchedule {
  final String id;
  final String residentName;
  final String shiftName;
  final DateTime startsAt;
  final DateTime endsAt;

  const DutySchedule({
    required this.id,
    required this.residentName,
    required this.shiftName,
    required this.startsAt,
    required this.endsAt,
  });

  factory DutySchedule.fromMap(Map<String, dynamic> row) => DutySchedule(
        id: row['id'] as String,
        residentName: row['resident_name'] as String,
        shiftName: row['shift_name'] as String,
        startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(row['ends_at'] as String).toLocal(),
      );
}

class DutyScheduleDraft {
  final String residentName;
  final String shiftName;
  final DateTime startsAt;
  final DateTime endsAt;

  const DutyScheduleDraft({
    required this.residentName,
    required this.shiftName,
    required this.startsAt,
    required this.endsAt,
  });
}

class DutyScheduleService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<List<DutySchedule>> watchAll() => _client
      .from('duty_schedules')
      .stream(primaryKey: ['id'])
      .order('starts_at')
      .map((rows) => rows.map(DutySchedule.fromMap).toList());

  static Future<void> create(DutyScheduleDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');

    await _client.from('duty_schedules').insert({
      'resident_name': draft.residentName.trim(),
      'shift_name': draft.shiftName,
      'starts_at': draft.startsAt.toUtc().toIso8601String(),
      'ends_at': draft.endsAt.toUtc().toIso8601String(),
      'created_by': user.id,
    });
  }

  static Future<void> delete(String id) async {
    await _client.from('duty_schedules').delete().eq('id', id);
  }
}
