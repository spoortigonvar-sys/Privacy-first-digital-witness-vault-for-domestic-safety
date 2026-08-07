import 'package:video_player/video_player.dart';
import '../utils/constants.dart';
import 'package:flutter/material.dart';
import '../models/evidence_model.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class EvidenceDetailScreen extends StatefulWidget {
  final EvidenceModel evidence;

  const EvidenceDetailScreen({super.key, required this.evidence});

  @override
  State<EvidenceDetailScreen> createState() => _EvidenceDetailScreenState();
}

class _EvidenceDetailScreenState extends State<EvidenceDetailScreen> {
  bool _verifying = false;
  Map<String, dynamic>? _verifyResult;

  VideoPlayerController? _controller;
  bool _loadingVideo = true;

  Future<void> _verifyNow() async {
    setState(() => _verifying = true);
    final result =
        await ApiService.verifyEvidence(widget.evidence.evidenceId);
    if (mounted) {
      setState(() {
        _verifying = false;
        _verifyResult = result['success'] == true ? result['data'] : null;
      });

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Verification failed'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.evidence;

    return Scaffold(
      appBar: AppBar(title: const Text('Evidence Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.description_outlined,
                              color: AppTheme.accent, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.filename,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(e.evidenceId,
                                  style: const TextStyle(
                                      color: AppTheme.textLight,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _detailRow('Evidence ID', e.evidenceId),
                    _detailRow('Filename', e.filename),
                    if (e.sha256.isNotEmpty)
                      _detailRow('SHA-256', e.sha256, mono: true),
                    _detailRow('Upload Time', e.uploadTime),
                    _detailRow('Status', e.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Integrity Verification',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Verify this evidence file has not been tampered with since upload.',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _verifying ? null : _verifyNow,
                      icon: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: Text(_verifying ? 'Verifying...' : 'Verify Now'),
                    ),
                    if (_verifyResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (_verifyResult!['verified'] == true
                                  ? AppTheme.success
                                  : AppTheme.danger)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _verifyResult!['verified'] == true
                                ? AppTheme.success
                                : AppTheme.danger,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _verifyResult!['verified'] == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _verifyResult!['verified'] == true
                                  ? AppTheme.success
                                  : AppTheme.danger,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _verifyResult!['message'] ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: mono ? 12 : 14,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
