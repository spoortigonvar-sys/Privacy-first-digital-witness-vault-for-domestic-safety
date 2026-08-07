class EvidenceModel {
  final String evidenceId;
  final String filename;
  final String sha256;
  final String uploadTime;
  final String storagePath;
  final String status;

  EvidenceModel({
    required this.evidenceId,
    required this.filename,
    required this.sha256,
    required this.uploadTime,
    required this.storagePath,
    required this.status,
  });

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    return EvidenceModel(
      evidenceId: json['evidence_id'] ?? '',
      filename: json['filename'] ?? '',
      sha256: json['sha256'] ?? '',
      uploadTime: json['upload_time'] ?? '',
      storagePath: json['storage_path'] ?? '',
      status: json['status'] ?? '',
    );
  }

  /// Parse from dashboard recent list which returns raw arrays [id, filename, time, status]
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
