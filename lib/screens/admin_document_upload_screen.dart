import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';
import '../services/decision_document_service.dart';

class AdminDocumentUploadScreen extends StatefulWidget {
  final String subject;

  const AdminDocumentUploadScreen({required this.subject, super.key});

  @override
  State<AdminDocumentUploadScreen> createState() =>
      _AdminDocumentUploadScreenState();
}

class _AdminDocumentUploadScreenState extends State<AdminDocumentUploadScreen> {
  DecisionDocumentFile? _document;
  bool _selecting = false;

  Future<void> _chooseDocument() async {
    setState(() => _selecting = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _message('File tidak dapat dibaca. Coba pilih ulang.');
        return;
      }
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        _message('Ukuran dokumen maksimal 10 MB.');
        return;
      }
      final extension = file.extension?.toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        _ => null,
      };
      if (contentType == null) {
        _message('Format dokumen harus PDF, DOC, atau DOCX.');
        return;
      }
      setState(() => _document = DecisionDocumentFile(
            name: file.name,
            bytes: bytes,
            contentType: contentType,
          ));
    } catch (error) {
      _message('Dokumen gagal dipilih: $error');
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const SirtLogo(),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                children: [
                  Text(
                    'Upload Surat',
                    style: const TextStyle(
                        color: appInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text('Dokumen keputusan: ${widget.subject}',
                      style: const TextStyle(color: appMuted, fontSize: 11)),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _selecting ? null : _chooseDocument,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 172,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: appBorder),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _document == null
                                ? Icons.upload_file_outlined
                                : Icons.description_outlined,
                            size: 30,
                            color: appInk,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            _selecting
                                ? 'Memilih dokumen…'
                                : _document?.name ?? 'Pilih dokumen surat',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: appInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text('PDF, DOC, atau DOCX · Maksimal 10 MB',
                              style: TextStyle(color: appMuted, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: _document == null
                          ? null
                          : () => Navigator.pop(context, _document),
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: appGreen.withValues(alpha: .45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Kirim'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
