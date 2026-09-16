import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/dashboard_model.dart';
import '../models/evidence_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class EvidenceHistoryScreen extends StatefulWidget {
  const EvidenceHistoryScreen({super.key});

  @override
  State<EvidenceHistoryScreen> createState() =>
      _EvidenceHistoryScreenState();
}

class _EvidenceHistoryScreenState
    extends State<EvidenceHistoryScreen> {

  DashboardModel? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // -------------------------------------------------------
  // LOAD DASHBOARD
  // -------------------------------------------------------

  Future<void> _load() async {

    setState(() => _loading = true);

    final dashboard =
        await ApiService.getDashboard();

    if (mounted) {
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    }
  }

  // -------------------------------------------------------
  // OPEN EVIDENCE WITH COMPLETE AI DATA
  // -------------------------------------------------------

  Future<void> _openEvidence(
  EvidenceModel dashboardItem,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.accent,
        ),
      );
    },
  );

  try {
    final result = await ApiService.getMyEvidence();

    if (!mounted) return;

    Navigator.pop(context);

    if (result["success"] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result["message"] ??
                "Unable to load evidence.",
          ),
        ),
      );
      return;
    }

    final List<dynamic> evidenceList =
        result["evidence"] ?? [];

    EvidenceModel? completeEvidence;

    // Find the selected evidence by evidence ID
    for (final item in evidenceList) {
      if (item is Map<String, dynamic>) {
        final id = item["evidence_id"]?.toString();

        if (id == dashboardItem.evidenceId) {
          completeEvidence =
              EvidenceModel.fromJson(item);
          break;
        }
      }
    }

    if (completeEvidence == null) {
      debugPrint(
        "Selected evidence ID: ${dashboardItem.evidenceId}",
      );

      debugPrint(
        "Evidence returned by API:",
      );

      for (final item in evidenceList) {
        debugPrint(
          item.toString(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Evidence details not found.",
          ),
        ),
      );

      return;
    }

    Navigator.pushNamed(
      context,
      AppConstants.evidenceDetailRoute,
      arguments: completeEvidence,
    );

  } catch (e) {
    if (!mounted) return;

    Navigator.pop(context);

    debugPrint(
      "Error opening evidence: $e",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Unable to load evidence details.",
        ),
      ),
    );
  }
}

  // -------------------------------------------------------
  // BUILD
  // -------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    final recent =
        _dashboard?.recent ?? [];

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'Evidence Vault',
        ),
      ),

      body: _loading

          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accent,
              ),
            )

          : RefreshIndicator(

              onRefresh: _load,

              color: AppTheme.accent,

              child: recent.isEmpty

                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),

                      children: const [

                        SizedBox(height: 120),

                        Icon(
                          Icons.folder_off_outlined,
                          size: 64,
                          color: AppTheme.textLight,
                        ),

                        SizedBox(height: 16),

                        Center(
                          child: Text(
                            'No evidence uploaded yet.',
                            style: TextStyle(
                              color: AppTheme.textLight,
                            ),
                          ),
                        ),
                      ],
                    )

                  : ListView.builder(

                      physics:
                          const AlwaysScrollableScrollPhysics(),

                      padding:
                          const EdgeInsets.all(16),

                      itemCount:
                          recent.length,

                      itemBuilder:
                          (context, index) {

                        final item =
                            recent[index];

                        return _EvidenceListTile(
                          item: item,

                          onTap: () {
                            _openEvidence(item);
                          },
                        );
                      },
                    ),
            ),
    );
  }
}


// ===========================================================
// EVIDENCE LIST TILE
// ===========================================================

class _EvidenceListTile
    extends StatelessWidget {

  final EvidenceModel item;
  final VoidCallback onTap;

  const _EvidenceListTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Card(

      child: ListTile(

        contentPadding:
            const EdgeInsets.all(12),

        leading: Container(

          width: 44,
          height: 44,

          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius:
                BorderRadius.circular(10),
          ),

          child: const Icon(
            Icons.description_outlined,
            color: AppTheme.accent,
          ),
        ),

        title: Text(
          item.filename,

          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),

          overflow:
              TextOverflow.ellipsis,
        ),

        subtitle: Padding(

          padding:
              const EdgeInsets.only(top: 4),

          child: Text(
            '${item.evidenceId}  ·  ${item.uploadTime}',

            style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 12,
            ),
          ),
        ),

        trailing: Chip(

          label: Text(
            item.status,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),

          backgroundColor:
              AppTheme.success.withOpacity(0.25),

          side: BorderSide.none,
        ),

        onTap: onTap,
      ),
    );
  }
}