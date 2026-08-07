import 'evidence_model.dart';

class DashboardModel {
  final int total;
  final int verified;
  final double storage;
  final List<EvidenceModel> recent;

  DashboardModel({
    required this.total,
    required this.verified,
    required this.storage,
    required this.recent,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      total: json['total'] ?? 0,
      verified: json['verified'] ?? 0,
      storage: (json['storage'] ?? 0).toDouble(),
      recent: (json['recent'] as List<dynamic>)
          .map(
            (e) => EvidenceModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}