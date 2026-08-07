import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/dashboard_model.dart';
import '../models/evidence_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class EvidenceHistoryScreen extends StatefulWidget {
  const EvidenceHistoryScreen({super.key});

  @override
  State<EvidenceHistoryScreen> createState() => _EvidenceHistoryScreenState();
}

class _EvidenceHistoryScreenState extends State<EvidenceHistoryScreen> {
  DashboardModel? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dashboard = await ApiService.getDashboard();
    if (mounted) {
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = _dashboard?.recent ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Evidence Vault')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.accent,
              child: recent.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.folder_off_outlined,
                            size: 64, color: AppTheme.textLight),
                        SizedBox(height: 16),
                        Center(
                          child: Text(
                            'No evidence uploaded yet.',
                            style: TextStyle(color: AppTheme.textLight),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: recent.length,
                      itemBuilder: (context, index) {
                        final item = recent[index];
                        return _EvidenceListTile(item: item);
                      },
                    ),
            ),
    );
  }
}

class _EvidenceListTile extends StatelessWidget {
  final EvidenceModel item;

  const _EvidenceListTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description_outlined,
              color: AppTheme.accent),
        ),
        title: Text(
          item.filename,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${item.evidenceId}  ·  ${item.uploadTime}',
            style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
          ),
        ),
        trailing: Chip(
          label: Text(
            item.status,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          backgroundColor: AppTheme.success.withOpacity(0.25),
          side: BorderSide.none,
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppConstants.evidenceDetailRoute,
            arguments: item,
          );
        },
      ),
    );
  }
}
