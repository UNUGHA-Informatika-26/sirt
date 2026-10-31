import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/decision_document_service.dart';
import '../utils/document_link_stub.dart'
    if (dart.library.html) '../utils/document_link_web.dart' as document_link;

class DecisionDocumentButton extends StatefulWidget {
  final String path;
  const DecisionDocumentButton({required this.path, super.key});

  @override
  State<DecisionDocumentButton> createState() => _DecisionDocumentButtonState();
}

class _DecisionDocumentButtonState extends State<DecisionDocumentButton> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    try {
      final copied = await document_link.openDecisionDocument(
        () => DecisionDocumentService.createViewUrl(widget.path),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(copied
            ? 'Dokumen dibuka di tab baru.'
            : 'Tautan dokumen disalin. Buka tautan tersebut di browser.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Dokumen gagal dibuka: $error'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: _loading ? null : _open,
        style: TextButton.styleFrom(
          foregroundColor: appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: _loading
            ? const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : const Icon(Icons.download_outlined, size: 14),
        label: const Text('Lihat surat', style: TextStyle(fontSize: 9)),
      );
}
