import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class DecisionDocumentFile {
  final String name;
  final Uint8List bytes;
  final String contentType;

  const DecisionDocumentFile({
    required this.name,
    required this.bytes,
    required this.contentType,
  });
}

class DecisionDocumentService {
  static const bucket = 'decision-documents';
  static SupabaseClient get _client => Supabase.instance.client;

  static String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static Future<String> upload(
    DecisionDocumentFile document, {
    required String userId,
    required String requestId,
  }) async {
    final path = '$userId/$requestId/${_safeFileName(document.name)}';
    await _client.storage.from(bucket).uploadBinary(
          path,
          document.bytes,
          fileOptions: FileOptions(
            contentType: document.contentType,
            upsert: false,
          ),
        );
    return path;
  }

  static Future<void> remove(String path) async {
    await _client.storage.from(bucket).remove([path]);
  }

  static Future<String> createViewUrl(String path) =>
      _client.storage.from(bucket).createSignedUrl(path, 900);
}
