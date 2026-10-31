import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/sirt_logo.dart';
import '../app_colors.dart';

class UploadedDocument {
  final String fileName;
  final Uint8List bytes;

  const UploadedDocument({required this.fileName, required this.bytes});
}

class AdminUploadDocumentScreen extends StatefulWidget {
  final String requestTitle;

  const AdminUploadDocumentScreen({
    required this.requestTitle,
    super.key,
  });

  @override
  State<AdminUploadDocumentScreen> createState() =>
      _AdminUploadDocumentScreenState();
}

class _AdminUploadDocumentScreenState extends State<AdminUploadDocumentScreen> {
  PlatformFile? _selectedFile;
  bool _busy = false;

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (!mounted || result == null) return;

      final file = result.files.single;
      if (file.bytes == null) {
        _showMessage('Berkas tidak bisa dibaca. Pilih berkas lain.');
        return;
      }
      if (file.size > 10 * 1024 * 1024) {
        _showMessage('Ukuran berkas maksimal 10 MB.');
        return;
      }
      setState(() => _selectedFile = file);
    } catch (error) {
      _showMessage('Gagal membuka pemilih berkas: $error');
    }
  }

  void _sendFile() {
    final file = _selectedFile;
    if (file == null || file.bytes == null) {
      _showMessage('Pilih berkas terlebih dahulu.');
      return;
    }
    setState(() => _busy = true);
    Navigator.of(context).pop(
      UploadedDocument(fileName: file.name, bytes: file.bytes!),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const SirtLogo(),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                children: [
                  const Text(
                    'Upload Surat',
                    style: TextStyle(
                        color: appInk,
                        fontSize: 21,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.requestTitle,
                      style: const TextStyle(color: appMuted, fontSize: 12)),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _busy ? null : _chooseFile,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 170,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: _selectedFile == null
                                ? appBorder
                                : appGreen,
                            width: _selectedFile == null ? 1 : 1.5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _selectedFile == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_outlined,
                                    color: appInk, size: 28),
                                SizedBox(height: 9),
                                Text('Pilih berkas surat',
                                    style: TextStyle(
                                        color: appMuted, fontSize: 12)),
                                SizedBox(height: 4),
                                Text('PDF, JPG, atau PNG · Maksimal 10 MB',
                                    style: TextStyle(
                                        color: appMuted, fontSize: 10)),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.description_outlined,
                                    color: appGreen, size: 30),
                                const SizedBox(height: 10),
                                Text(
                                  _selectedFile!.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: appInk,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(_formatBytes(_selectedFile!.size),
                                    style: const TextStyle(
                                        color: appMuted, fontSize: 10)),
                                TextButton(
                                  onPressed: _chooseFile,
                                  child: const Text('Ganti berkas'),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: _selectedFile == null || _busy
                          ? null
                          : _sendFile,
                      style: FilledButton.styleFrom(
                        backgroundColor: appGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB8D8D0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
