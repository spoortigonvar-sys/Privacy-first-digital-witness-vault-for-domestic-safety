import 'package:flutter/material.dart';

import '../services/api_service.dart';

class MyEvidenceScreen extends StatefulWidget {
  const MyEvidenceScreen({super.key});

  @override
  State<MyEvidenceScreen> createState() => _MyEvidenceScreenState();
}

class _MyEvidenceScreenState extends State<MyEvidenceScreen> {
  bool _loading = true;
  String? _error;

  List<dynamic> _evidence = [];

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getMyEvidence();

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _evidence = result['evidence'] ?? [];
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Unable to load evidence';
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Unable to connect to the Vault';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Evidence'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvidence,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_evidence.isEmpty) {
      return const Center(
        child: Text(
          'No evidence found.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvidence,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _evidence.length,
        itemBuilder: (context, index) {
          final item = _evidence[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.videocam),
              ),
              title: Text(
                item['evidence_id'] ?? 'Unknown Evidence',
              ),
              subtitle: Text(
                '${item['filename'] ?? 'Video'}\n'
                '${item['upload_time'] ?? ''}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}