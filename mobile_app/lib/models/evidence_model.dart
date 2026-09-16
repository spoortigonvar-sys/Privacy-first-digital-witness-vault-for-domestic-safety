class EvidenceModel {
  final String evidenceId;
  final String filename;
  final String sha256;
  final String uploadTime;
  final String storagePath;
  final String status;

  // AI Analysis
  final bool violenceDetected;
  final double violenceProbability;
  final bool knifeDetected;
  final bool gunDetected;
  final bool dangerDetected;

  EvidenceModel({
    required this.evidenceId,
    required this.filename,
    required this.sha256,
    required this.uploadTime,
    required this.storagePath,
    required this.status,

    // AI Analysis
    this.violenceDetected = false,
    this.violenceProbability = 0.0,
    this.knifeDetected = false,
    this.gunDetected = false,
    this.dangerDetected = false,
  });

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    return EvidenceModel(
      evidenceId: json['evidence_id'] ?? '',
      filename: json['filename'] ?? '',
      sha256: json['sha256'] ?? '',
      uploadTime: json['upload_time'] ?? '',
      storagePath: json['storage_path'] ?? '',
      status: json['status'] ?? '',

      // AI Analysis
      violenceDetected: json['violence_detected'] ?? false,

      violenceProbability:
          (json['violence_probability'] ?? 0.0).toDouble(),

      knifeDetected: json['knife_detected'] ?? false,

      gunDetected: json['gun_detected'] ?? false,

      dangerDetected: json['danger_detected'] ?? false,
    );
  }

  /// Parse from dashboard recent list
  /// which returns raw arrays:
  /// [id, filename, sha256, uploadTime, storagePath, status]
  static EvidenceModel fromRawList(List<dynamic> row) {
    return EvidenceModel(
      evidenceId: row[0].toString(),
      filename: row[1].toString(),
      sha256: row[2].toString(),
      uploadTime: row[3].toString(),
      storagePath: row[4].toString(),
      status: row[5].toString(),
    );
  }
}