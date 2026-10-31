String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('profiles') || text.contains('PGRST')) {
    return 'Profil akun belum siap. Pastikan tabel profiles sudah dibuat di Supabase.';
  }
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Tidak bisa tersambung. Periksa internet dan konfigurasi Supabase.';
  }
  return text;
}
