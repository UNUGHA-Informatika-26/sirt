import 'package:flutter/services.dart';

Future<bool> openDecisionDocument(Future<String> Function() resolveUrl) async {
  final url = await resolveUrl();
  await Clipboard.setData(ClipboardData(text: url));
  return false;
}
