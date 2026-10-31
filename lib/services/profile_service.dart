import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<String?> watchMyAvatar(String userId) => _client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((rows) => rows.isEmpty ? null : rows.first['avatar_url'] as String?);

  static Future<void> saveMyAvatar(String avatarUrl) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Silakan masuk kembali.');
    final updated = await _client
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('id', user.id)
        .select('id')
        .maybeSingle();
    if (updated == null) throw StateError('Profil akun tidak ditemukan.');
  }
}
