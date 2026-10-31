import 'package:web/web.dart' as web;

Future<bool> openDecisionDocument(Future<String> Function() resolveUrl) async {
  final popup = web.window.open('about:blank', '_blank');
  if (popup == null) throw StateError('Browser memblokir jendela dokumen.');
  try {
    popup.location.href = await resolveUrl();
    return true;
  } catch (_) {
    popup.close();
    rethrow;
  }
}
