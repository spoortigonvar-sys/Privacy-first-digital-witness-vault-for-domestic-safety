import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class VerifyEvidenceScreen extends StatefulWidget {
  const VerifyEvidenceScreen({super.key});

  @override
  State<VerifyEvidenceScreen> createState() => _VerifyEvidenceScreenState();
}

class _VerifyEvidenceScreenState extends State<VerifyEvidenceScreen> {
  final _idController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter an Evidence ID');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    final res = await ApiService.verifyEvidence(id);

    if (mounted) {
      setState(() {
        _loading = false;
        if (res['success'] == true) {
          _result = res['data'];
        } else {
          _error = res['message'] ?? 'Verification failed';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Evidence')),
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
                    const Text('Verify Evidence Integrity',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter an Evidence ID (e.g. EV-1A2B3C4D) to check its SHA-256 integrity against the original upload.',
                      style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _idController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Evidence ID',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _verify,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search),
                      label: Text(_loading ? 'Verifying...' : 'Verify'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.white))),
                  ],
                ),
              ),
            if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_result!['verified'] == true
                          ? AppTheme.success
                          : AppTheme.danger)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _result!['verified'] == true
                        ? AppTheme.success
                        : AppTheme.danger,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _result!['verified'] == true
                              ? Icons.check_circle
                              : Icons.error,
                          color: _result!['verified'] == true
                              ? AppTheme.success
                              : AppTheme.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _result!['message'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_result!['sha256'] != null)
                      _hashRow('SHA-256', _result!['sha256']),
                    if (_result!['stored_hash'] != null)
                      _hashRow('Stored Hash', _result!['stored_hash']),
                    if (_result!['current_hash'] != null)
                      _hashRow('Current Hash', _result!['current_hash']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hashRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
