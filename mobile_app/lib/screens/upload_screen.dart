import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/evidence_model.dart';
import '../utils/app_theme.dart';
import '../widgets/loading_overlay.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  UserModel? _user;
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  double _progress = 0.0;
  EvidenceModel? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.loadUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        _lastResult = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0.15;
    });

    try {
      setState(() => _progress = 0.5);

      final result = await ApiService.uploadEvidence(_selectedFile!);

      setState(() => _progress = 1.0);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _lastResult = result['data'] as EvidenceModel);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidence Uploaded Successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Upload Failed'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload Failed'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Evidence')),
      body: LoadingOverlay(
        isLoading: _isUploading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Information',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 12),
                      _infoRow('Name', _user?.fullname ?? '-'),
                      _infoRow('Date', DateFormat('MM/dd/yyyy').format(now)),
                      _infoRow('Time', DateFormat('hh:mm:ss a').format(now)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upload Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload Evidence',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.accent,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: AppTheme.primaryDark,
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_upload_outlined,
                                  size: 48, color: AppTheme.accent),
                              const SizedBox(height: 12),
                              const Text('Tap to Select Video',
                                  style: TextStyle(color: Colors.white)),
                              const SizedBox(height: 8),
                              Text(
                                _fileName ?? 'No file selected',
                                style: const TextStyle(
                                    color: AppTheme.textLight, fontSize: 12),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isUploading) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 8,
                            backgroundColor: AppTheme.primaryDark,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _upload,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Evidence'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Evidence Summary',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 12),
                      if (_lastResult == null)
                        const Text('No evidence uploaded yet.',
                            style: TextStyle(color: AppTheme.textLight))
                      else ...[
                        _infoRow('Evidence ID', _lastResult!.evidenceId),
                        _infoRow('Filename', _lastResult!.filename),
                        _infoRow('SHA-256', _lastResult!.sha256,
                            selectable: true),
                        _infoRow('Upload Time', _lastResult!.uploadTime),
                        Row(
                          children: [
                            const Text('Status: ',
                                style:
                                    TextStyle(color: AppTheme.textLight)),
                            const Icon(Icons.circle,
                                color: AppTheme.success, size: 10),
                            const SizedBox(width: 4),
                            Text(_lastResult!.status,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(
                    color: AppTheme.textLight, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value,
                    style: const TextStyle(color: Colors.white, fontSize: 12))
                : Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
